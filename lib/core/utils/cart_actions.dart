import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/models/product_model.dart';
import 'package:shop/providers/cart_provider.dart';

Future<bool> addProductToCartFromCard(
  BuildContext context,
  ProductModel product,
) async {
  final success = await context.read<CartProvider>().addToCart(
    product,
    selectedOption: product.defaultPackOption,
  );

  if (!context.mounted) {
    return success;
  }

  final cartProvider = context.read<CartProvider>();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? '${product.title} added to cart.'
            : cartProvider.errorMessage ?? 'Unable to add this product.',
      ),
    ),
  );
  return success;
}
