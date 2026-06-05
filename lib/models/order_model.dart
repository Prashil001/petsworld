import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:shop/models/order_delivery_address_model.dart';
import 'package:shop/models/order_enums.dart';
import 'package:shop/models/order_item_model.dart';
import 'package:shop/models/order_payment_model.dart';
import 'package:shop/models/order_pricing_model.dart';

export 'order_enums.dart';

@immutable
class OrderModel {
  const OrderModel({
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.deliveryAddress,
    required this.items,
    required this.pricing,
    required this.payment,
    this.orderStatus = OrderStatus.placed,
    this.stockDecremented = false,
    this.createdAt,
    this.updatedAt,
  });

  final String orderId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final OrderDeliveryAddressModel deliveryAddress;
  final List<OrderItemModel> items;
  final OrderPricingModel pricing;
  final OrderPaymentModel payment;
  final OrderStatus orderStatus;

  /// True after the stock for this order's items has been reserved
  /// (decremented). Used by cancel flows to know whether to restore.
  final bool stockDecremented;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get id => orderId;
  String get customerName => userName;
  String get phoneNumber => userPhone;
  String get address => deliveryAddress.fullAddress;
  double get subtotal => pricing.subtotal;
  double get deliveryCharge => pricing.deliveryCharge;
  double get total => pricing.totalAmount;
  double get totalPrice => pricing.totalAmount;
  PaymentMethod get paymentMethod => payment.paymentMethod;
  PaymentStatus get paymentStatus => payment.paymentStatus;
  bool get isDelivered => orderStatus == OrderStatus.delivered;
  bool get isCancelled => orderStatus == OrderStatus.cancelled;
  bool get isShipped => orderStatus == OrderStatus.shipped;
  bool get isCompleted => isDelivered || isCancelled;
  bool get canUserCancel =>
      orderStatus == OrderStatus.placed || orderStatus == OrderStatus.confirmed;
  int get totalItems =>
      items.fold<int>(0, (totalQty, item) => totalQty + item.quantity);

  OrderModel copyWith({
    String? orderId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    OrderDeliveryAddressModel? deliveryAddress,
    List<OrderItemModel>? items,
    OrderPricingModel? pricing,
    OrderPaymentModel? payment,
    OrderStatus? orderStatus,
    bool? stockDecremented,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      pricing: pricing ?? this.pricing,
      payment: payment ?? this.payment,
      orderStatus: orderStatus ?? this.orderStatus,
      stockDecremented: stockDecremented ?? this.stockDecremented,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    final deliveryAddressData = data['deliveryAddress'];
    final pricingData = data['pricing'];
    final paymentData = data['payment'];

    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(OrderItemModel.fromMap)
        .toList();

    return OrderModel(
      orderId: data['orderId'] as String? ?? id,
      userId: data['userId'] as String? ?? '',
      userName:
          data['userName'] as String? ?? data['customerName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      userPhone:
          data['userPhone'] as String? ?? data['phoneNumber'] as String? ?? '',
      deliveryAddress: deliveryAddressData is Map
          ? OrderDeliveryAddressModel.fromMap(
              Map<String, dynamic>.from(deliveryAddressData),
            )
          : OrderDeliveryAddressModel(
              fullName: data['customerName'] as String? ?? '',
              phone: data['phoneNumber'] as String? ?? '',
              addressLine1: data['address'] as String? ?? '',
              city: '',
              state: '',
              pincode: '',
            ),
      items: items,
      pricing: pricingData is Map
          ? OrderPricingModel.fromMap(Map<String, dynamic>.from(pricingData))
          : OrderPricingModel(
              subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
              deliveryCharge: (data['deliveryCharge'] as num?)?.toDouble() ?? 0,
              discount: (data['discount'] as num?)?.toDouble() ?? 0,
              totalAmount:
                  (data['totalAmount'] as num?)?.toDouble() ??
                  (data['total'] as num?)?.toDouble() ??
                  0,
            ),
      payment: paymentData is Map
          ? OrderPaymentModel.fromMap(Map<String, dynamic>.from(paymentData))
          : OrderPaymentModel(
              paymentMethod: _paymentMethodFromString(
                data['paymentMethod'] as String?,
              ),
              paymentStatus: _paymentStatusFromString(
                data['paymentStatus'] as String?,
              ),
            ),
      orderStatus: _orderStatusFromString(data['orderStatus'] as String?),
      stockDecremented: data['stockDecremented'] as bool? ?? false,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'deliveryAddress': deliveryAddress.toMap(),
      'items': items.map((item) => item.toMap()).toList(),
      'pricing': pricing.toMap(),
      'payment': payment.toMap(),
      'orderStatus': orderStatus.name,
      'stockDecremented': stockDecremented,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'customerName': userName,
      'phoneNumber': userPhone,
      'address': deliveryAddress.fullAddress,
      'subtotal': pricing.subtotal,
      'deliveryCharge': pricing.deliveryCharge,
      'discount': pricing.discount,
      'total': pricing.totalAmount,
      'paymentMethod': payment.paymentMethod.name,
      'paymentStatus': payment.paymentStatus.name,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static PaymentMethod _paymentMethodFromString(String? value) {
    if (value == 'razorpay') return PaymentMethod.razorpay;
    return PaymentMethod.cod;
  }

  static PaymentStatus _paymentStatusFromString(String? value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }

  static OrderStatus _orderStatusFromString(String? value) {
    if (value == 'packed') return OrderStatus.confirmed;
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.placed,
    );
  }
}
