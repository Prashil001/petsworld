import 'package:flutter/foundation.dart';

import 'package:shop/models/product_model.dart';

@immutable
class CartItemModel {
  const CartItemModel({
    required this.product,
    required this.selectedOptionId,
    required this.selectedOptionLabel,
    required this.unitPrice,
    this.originalUnitPrice,
    this.quantity = 1,
  });

  final ProductModel product;
  final String selectedOptionId;
  final String selectedOptionLabel;
  final double unitPrice;
  final double? originalUnitPrice;
  final int quantity;

  String get id => '${product.id}::${selectedOptionId.trim().isEmpty ? 'default' : selectedOptionId.trim()}';
  bool get hasDiscount =>
      originalUnitPrice != null && originalUnitPrice! > unitPrice;
  double get totalPrice => unitPrice * quantity;
  String get displayName => selectedOptionLabel.trim().isEmpty
      ? product.name
      : '${product.name} (${selectedOptionLabel.trim()})';

  int get availableStock {
    if (!product.isActive) {
      return 0;
    }
    final optionId = selectedOptionId.trim();
    if (optionId.isNotEmpty && optionId != 'default') {
      for (final option in product.packOptions) {
        if (option.id == optionId) {
          return option.stockQuantity;
        }
      }
    }
    return product.stockQuantity;
  }

  bool get isOutOfStock => availableStock <= 0;
  bool get hasExceededStock => quantity > availableStock;

  CartItemModel copyWith({
    ProductModel? product,
    String? selectedOptionId,
    String? selectedOptionLabel,
    double? unitPrice,
    double? originalUnitPrice,
    int? quantity,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      selectedOptionLabel: selectedOptionLabel ?? this.selectedOptionLabel,
      unitPrice: unitPrice ?? this.unitPrice,
      originalUnitPrice: originalUnitPrice ?? this.originalUnitPrice,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartItemModel.fromMap(Map<String, dynamic> data) {
    return CartItemModel(
      product: ProductModel.fromMap(
        data['productId'] as String? ?? '',
        Map<String, dynamic>.from(
          data['product'] as Map? ?? <String, dynamic>{},
        ),
      ),
      selectedOptionId: data['selectedOptionId'] as String? ?? '',
      selectedOptionLabel: data['selectedOptionLabel'] as String? ?? '',
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      originalUnitPrice: (data['originalUnitPrice'] as num?)?.toDouble(),
      quantity: data['quantity'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': product.id,
      'product': product.toMap(),
      'selectedOptionId': selectedOptionId,
      'selectedOptionLabel': selectedOptionLabel,
      'unitPrice': unitPrice,
      'originalUnitPrice': originalUnitPrice,
      'quantity': quantity,
    };
  }
}
