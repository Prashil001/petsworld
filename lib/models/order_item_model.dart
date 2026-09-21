import 'package:flutter/foundation.dart';

import 'package:shop/models/cart_item_model.dart';

@immutable
class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.productPrice,
    this.originalProductPrice,
    required this.quantity,
    this.selectedOptionId = '',
    this.selectedOptionLabel = '',
  });

  final String productId;
  final String productName;
  final String imageUrl;
  final double productPrice;
  final double? originalProductPrice;
  final int quantity;
  final String selectedOptionId;
  final String selectedOptionLabel;

  String get name => selectedOptionLabel.trim().isEmpty
      ? productName
      : '$productName (${selectedOptionLabel.trim()})';
  double get unitPrice => productPrice;
  double? get originalUnitPrice => originalProductPrice;

  double get lineTotal => productPrice * quantity;

  factory OrderItemModel.fromCartItem(CartItemModel item) {
    return OrderItemModel(
      productId: item.product.id,
      productName: item.product.name,
      imageUrl: item.product.imageUrl,
      productPrice: item.unitPrice,
      originalProductPrice: item.originalUnitPrice,
      quantity: item.quantity,
      selectedOptionId: item.selectedOptionId,
      selectedOptionLabel: item.selectedOptionLabel,
    );
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      productId: data['productId'] as String? ?? '',
      productName:
          data['productName'] as String? ?? data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      productPrice:
          (data['productPrice'] as num?)?.toDouble() ??
          (data['unitPrice'] as num?)?.toDouble() ??
          0,
      originalProductPrice:
          (data['originalProductPrice'] as num?)?.toDouble() ??
          (data['originalUnitPrice'] as num?)?.toDouble(),
      quantity: data['quantity'] as int? ?? 0,
      selectedOptionId: data['selectedOptionId'] as String? ?? '',
      selectedOptionLabel: data['selectedOptionLabel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'productPrice': productPrice,
      'originalProductPrice': originalProductPrice,
      'quantity': quantity,
      'selectedOptionId': selectedOptionId,
      'selectedOptionLabel': selectedOptionLabel,
      'name': productName,
      'unitPrice': productPrice,
      'originalUnitPrice': originalProductPrice,
      'lineTotal': lineTotal,
    };
  }
}
