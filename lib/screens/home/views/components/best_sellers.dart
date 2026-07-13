import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/core/utils/cart_actions.dart';
import 'package:shop/core/widgets/section_empty_state.dart';
import 'package:shop/providers/product_provider.dart';

import '../../../../constants.dart';
import '../../../../route/route_constants.dart';

class BestSellers extends StatelessWidget {
  const BestSellers({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.bestSellerProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: defaultPadding / 2),
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Best sellers",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (products.isEmpty)
          const SectionEmptyState(
            title: "No best sellers yet",
            message:
                "Your most-purchased pet products will appear here once the catalog is live.",
          )
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  left: defaultPadding,
                  right: index == products.length - 1 ? defaultPadding : 0,
                ),
                child: ProductCard(
                  image: products[index].image,
                  brandName: products[index].brandName,
                  title: products[index].title,
                  price: products[index].price,
                  priceAfetDiscount: products[index].priceAfetDiscount,
                  dicountpercent: products[index].dicountpercent,
                  isSaved: productProvider.isBookmarked(products[index].id),
                  onToggleSaved: () {
                    context.read<ProductProvider>().toggleBookmark(
                      products[index],
                    );
                  },
                  onAddToCart: () =>
                      addProductToCartFromCard(context, products[index]),
                  press: () {
                    Navigator.pushNamed(
                      context,
                      productDetailsScreenRoute,
                      arguments: products[index],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
