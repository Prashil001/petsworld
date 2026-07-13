import 'package:flutter/foundation.dart';

import 'package:shop/core/services/order_invoice_service.dart';
import 'package:shop/core/services/pdf_invoice_service.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({
    required OrderRepository orderRepository,
    PdfInvoiceService? pdfInvoiceService,
    OrderInvoiceService? orderInvoiceService,
  }) : _orderRepository = orderRepository,
       _pdfInvoiceService = pdfInvoiceService ?? PdfInvoiceService(),
       _orderInvoiceService =
           orderInvoiceService ??
           OrderInvoiceService(pdfInvoiceService: pdfInvoiceService);

  final OrderRepository _orderRepository;
  final PdfInvoiceService _pdfInvoiceService;
  final OrderInvoiceService _orderInvoiceService;

  List<OrderModel> _orders = <OrderModel>[];
  bool _isLoading = false;
  String? _errorMessage;
  String? _invoiceErrorMessage;
  String? _userId;

  List<OrderModel> get orders => List<OrderModel>.unmodifiable(_orders);
  List<OrderModel> get pendingOrders => _orders
      .where(
        (order) =>
            order.orderStatus == OrderStatus.placed ||
            order.orderStatus == OrderStatus.confirmed ||
            order.orderStatus == OrderStatus.shipped,
      )
      .toList();
  List<OrderModel> get completedOrders => _orders
      .where(
        (order) =>
            order.orderStatus == OrderStatus.delivered ||
            order.orderStatus == OrderStatus.cancelled,
      )
      .toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get invoiceErrorMessage => _invoiceErrorMessage;

  void addOrder(OrderModel order) {
    final index = _orders.indexWhere((current) => current.id == order.id);
    if (index == -1) {
      _orders.insert(0, order);
    } else {
      _orders[index] = order;
    }
    notifyListeners();
  }

  Future<void> syncForUser(String? userId) async {
    if (_userId == userId) {
      return;
    }

    _userId = userId;
    _orders = <OrderModel>[];
    notifyListeners();

    if (userId == null || userId.isEmpty) {
      return;
    }

    await loadUserOrders(userId);
  }

  Future<void> loadUserOrders(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _orderRepository.getUserOrders(userId);
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<OrderPlacementResult?> placeOrder(OrderModel order) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedOrder = await _orderRepository.placeOrder(order);
      final invoiceBytes = await _pdfInvoiceService.buildInvoice(savedOrder);
      _orders = <OrderModel>[savedOrder, ..._orders];
      return OrderPlacementResult(
        order: savedOrder,
        invoiceBytes: invoiceBytes,
      );
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _orderRepository.updateOrderStatus(orderId, status);
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(orderStatus: status);
      }
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> cancelOrder({
    required String orderId,
    required String userId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _orderRepository.cancelOrder(orderId: orderId, userId: userId);
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          orderStatus: OrderStatus.cancelled,
        );
      }
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OrderInvoiceResult?> saveInvoice(OrderModel order) async {
    _invoiceErrorMessage = null;
    notifyListeners();

    try {
      return await _orderInvoiceService.saveInvoice(order);
    } catch (error) {
      _invoiceErrorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }
}

class OrderPlacementResult {
  const OrderPlacementResult({required this.order, required this.invoiceBytes});

  final OrderModel order;
  final Uint8List invoiceBytes;
}
