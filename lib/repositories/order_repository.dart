import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:shop/models/order_item_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/models/product_option_model.dart';

abstract class OrderRepository {
  Future<void> saveOrder(OrderModel order);
  Future<OrderModel> placeOrder(OrderModel order);
  Future<List<OrderModel>> getUserOrders(String userId);
  Future<List<OrderModel>> getAllOrders();
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> cancelOrder({required String orderId, required String userId});
}

class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  bool get _isReady => Firebase.apps.isNotEmpty;

  @override
  Future<void> saveOrder(OrderModel order) async {
    _ensureReady();

    final docRef = order.orderId.trim().isEmpty
        ? _db.collection('orders').doc()
        : _db.collection('orders').doc(order.orderId);
    final now = DateTime.now();
    final normalizedOrder = order.copyWith(
      orderId: docRef.id,
      updatedAt: now,
      createdAt: order.createdAt ?? now,
    );
    final payload = normalizedOrder.toMap();

    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['timestamp'] = FieldValue.serverTimestamp();
    payload.remove('stockDecremented');
    if (order.createdAt == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  @override
  Future<OrderModel> placeOrder(OrderModel order) async {
    _ensureReady();
    final docRef = _db.collection('orders').doc();
    final now = DateTime.now();
    final payload = order
        .copyWith(
          orderId: docRef.id,
          createdAt: order.createdAt ?? now,
          updatedAt: now,
        )
        .toMap();

    payload['timestamp'] = FieldValue.serverTimestamp();
    payload['createdAt'] = FieldValue.serverTimestamp();
    payload['updatedAt'] = FieldValue.serverTimestamp();

    final batch = _db.batch();
    batch.set(docRef, payload, SetOptions(merge: true));
    await batch.commit();

    final savedDoc = await docRef.get();
    final data = savedDoc.data();
    if (data == null) {
      throw StateError('Order was created but could not be loaded again.');
    }
    return OrderModel.fromMap(savedDoc.id, data);
  }

  @override
  Future<List<OrderModel>> getUserOrders(String userId) async {
    if (!_isReady || userId.trim().isEmpty) {
      return const <OrderModel>[];
    }

    final snapshot = await _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .get();

    final orders =
        snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

    return orders;
  }

  @override
  Future<List<OrderModel>> getAllOrders() async {
    if (!_isReady) {
      return const <OrderModel>[];
    }

    final snapshot = await _db.collection('orders').get();

    final orders =
        snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

    return orders;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    _ensureReady();
    await _db.runTransaction((transaction) async {
      final docRef = _db.collection('orders').doc(orderId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Order not found.');
      }

      final current = OrderModel.fromMap(snapshot.id, snapshot.data()!);
      if (current.isCompleted) {
        throw StateError('Delivered or cancelled orders cannot be changed.');
      }

      final updates = <String, dynamic>{
        'orderStatus': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // If admin moves the order to cancelled, restore the reserved stock
      // in the same transaction so other shoppers can buy those units.
      if (status == OrderStatus.cancelled && current.stockDecremented) {
        await _restoreStockForItems(
          transaction: transaction,
          items: current.items,
        );
        updates['stockDecremented'] = false;
      }

      transaction.update(docRef, updates);
    });
  }

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String userId,
  }) async {
    _ensureReady();

    await _db.runTransaction((transaction) async {
      final docRef = _db.collection('orders').doc(orderId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Order not found.');
      }

      final order = OrderModel.fromMap(snapshot.id, snapshot.data()!);
      if (order.userId != userId) {
        throw StateError('You can only cancel your own orders.');
      }
      if (!order.canUserCancel) {
        throw StateError('This order can no longer be cancelled.');
      }

      final updates = <String, dynamic>{
        'orderStatus': OrderStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Restore reserved stock in the same transaction.
      if (order.stockDecremented) {
        await _restoreStockForItems(
          transaction: transaction,
          items: order.items,
        );
        updates['stockDecremented'] = false;
      }

      transaction.update(docRef, updates);
    });
  }

  /// Restores stock for each order item inside the given Firestore [transaction].
  /// Groups items by product so multiple cart lines for the same product
  /// produce a single write. Reads every product first (Firestore requires
  /// all reads before any writes in a transaction), then applies updates.
  ///
  /// - Products that no longer exist are skipped silently.
  /// - Packs that no longer exist fall back to incrementing the top-level
  ///   stock so units aren't lost.
  Future<void> _restoreStockForItems({
    required Transaction transaction,
    required List<OrderItemModel> items,
  }) async {
    // Group items by productId (handles multi-pack purchases of the same product).
    final byProduct = <String, List<OrderItemModel>>{};
    for (final item in items) {
      final id = item.productId.trim();
      if (id.isEmpty || item.quantity <= 0) continue;
      (byProduct[id] ??= <OrderItemModel>[]).add(item);
    }
    if (byProduct.isEmpty) return;

    // Phase 1 — read every affected product and compute the full update payload.
    final pendingUpdates = <DocumentReference, Map<String, dynamic>>{};
    for (final entry in byProduct.entries) {
      final productRef = _db.collection('products').doc(entry.key);
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) continue;

      final product = ProductModel.fromMap(
        snapshot.id,
        snapshot.data() ?? <String, dynamic>{},
      );

      if (product.packOptions.isNotEmpty) {
        final updatedPacks = product.packOptions.toList();
        var fallbackStockBump = 0;
        for (final item in entry.value) {
          final idx = updatedPacks.indexWhere(
            (p) => p.id == item.selectedOptionId,
          );
          if (idx == -1) {
            fallbackStockBump += item.quantity;
          } else {
            updatedPacks[idx] = updatedPacks[idx].copyWith(
              stockQuantity: updatedPacks[idx].stockQuantity + item.quantity,
            );
          }
        }
        pendingUpdates[productRef] = <String, dynamic>{
          'packOptions': updatedPacks.map((p) => p.toMap()).toList(),
          'stockQuantity':
              _updatedProductPrimaryStock(updatedPacks) + fallbackStockBump,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else {
        final totalQty = entry.value.fold<int>(0, (s, i) => s + i.quantity);
        pendingUpdates[productRef] = <String, dynamic>{
          'stockQuantity': product.stockQuantity + totalQty,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }
    }

    // Phase 2 — apply all writes (after every read has completed).
    pendingUpdates.forEach((ref, data) => transaction.update(ref, data));
  }

  void _ensureReady() {
    if (!_isReady) {
      throw StateError(
        'Firebase is not configured yet. Run flutterfire configure and add '
        'the platform config files before using orders.',
      );
    }
  }

  int _updatedProductPrimaryStock(List<ProductOptionModel> updatedOptions) {
    if (updatedOptions.isEmpty) return 0;
    for (final option in updatedOptions) {
      if (option.isDefault) {
        return option.stockQuantity;
      }
    }
    return updatedOptions.first.stockQuantity;
  }
}
