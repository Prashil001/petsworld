import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/core/utils/cart_actions.dart';
import 'package:shop/core/widgets/section_empty_state.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/screen_export.dart';

import '../../../../constants.dart';

class PopularProducts extends StatelessWidget {
  const PopularProducts({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.catalogProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: defaultPadding / 2),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: defaultPadding,
            vertical: defaultPadding / 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${products.length} items',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (products.isEmpty)
          const SectionEmptyState(
            title: 'No products yet',
            message:
                'Add products from the admin panel and they will appear here automatically.',
          )
        else
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: defaultPadding,
                crossAxisSpacing: defaultPadding,
                childAspectRatio: 0.64,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(
                  image: product.image,
                  brandName: product.brandName,
                  title: product.title,
                  price: product.price,
                  priceAfetDiscount: product.priceAfetDiscount,
                  dicountpercent: product.dicountpercent,
                  isSaved: productProvider.isBookmarked(product.id),
                  onToggleSaved: () {
                    context.read<ProductProvider>().toggleBookmark(product);
                  },
                  onAddToCart: () => addProductToCartFromCard(context, product),
                  press: () {
                    Navigator.pushNamed(
                      context,
                      productDetailsScreenRoute,
                      arguments: product,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
