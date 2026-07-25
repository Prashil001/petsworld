import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/models/product_model.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/core/utils/auth_required.dart';

Future<bool> addProductToCartFromCard(
  BuildContext context,
  ProductModel product,
) async {
  if (!requireAuthenticatedUser(
    context,
    message: 'Please log in to add items to your cart.',
  )) {
    return false;
  }

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
