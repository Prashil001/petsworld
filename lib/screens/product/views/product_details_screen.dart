import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/core/utils/cart_actions.dart';
import 'package:shop/core/widgets/feature_placeholder_screen.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/product/views/product_returns_screen.dart';

import 'components/notify_me_card.dart';
import 'components/product_images.dart';
import 'components/product_info.dart';
import 'components/product_list_tile.dart';
import 'product_buy_now_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final ProductModel? product;

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return const FeaturePlaceholderScreen(
        title: "Product unavailable",
        description:
            "This product could not be loaded right now. Please try again in a moment.",
      );
    }

    final productProvider = context.watch<ProductProvider>();
    final currentProduct =
        productProvider.catalogProducts
            .where((item) => item.id == product!.id)
            .firstOrNull ??
        product!;
    final totalStock = currentProduct.hasPackOptions
        ? currentProduct.totalPackStock
        : currentProduct.stockQuantity;
    final isProductAvailable = currentProduct.isActive && totalStock > 0;
    final relatedProducts = context
        .watch<ProductProvider>()
        .popularProducts
        .where((item) => item.id != currentProduct.id)
        .take(4)
        .toList();
    final productImages = currentProduct.galleryImages.isEmpty
        ? const <String>['']
        : currentProduct.galleryImages;
    final displayPrice =
        currentProduct.defaultPackOption?.effectivePrice ??
        currentProduct.salePrice ??
        currentProduct.price;
    final isBookmarked = context.watch<ProductProvider>().isBookmarked(
      currentProduct.id,
    );

    return Scaffold(
      bottomNavigationBar: isProductAvailable
          ? CartButton(
              price: displayPrice,
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: ProductBuyNowScreen(product: currentProduct),
                );
              },
            )
          : NotifyMeCard(isNotify: false, onChanged: (value) {}),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              actions: [
                IconButton(
                  onPressed: () async {
                    final productProvider = context.read<ProductProvider>();
                    final success = await productProvider.toggleBookmark(
                      currentProduct,
                    );
                    if (!context.mounted || success) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          productProvider.errorMessage ??
                              'Unable to save this product right now.',
                        ),
                      ),
                    );
                  },
                  icon: SvgPicture.asset(
                    "assets/icons/Bookmark.svg",
                    colorFilter: ColorFilter.mode(
                      isBookmarked
                          ? primaryColor
                          : (Theme.of(context).textTheme.bodyLarge?.color ??
                                blackColor80),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
            ProductImages(images: productImages),
            ProductInfo(
              brand: currentProduct.brandName.isEmpty
                  ? currentProduct.categoryName
                  : currentProduct.brandName,
              title: currentProduct.title,
              isAvailable: isProductAvailable,
              description: currentProduct.description,
            ),
            ProductListTile(
              svgSrc: "assets/icons/Delivery.svg",
              title: "Delivery information",
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: const _DeliveryInformationSheet(),
                );
              },
            ),
            ProductListTile(
              svgSrc: "assets/icons/Return.svg",
              title: "Care policy",
              isShowBottomBorder: true,
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: const ProductReturnsScreen(),
                );
              },
            ),
            if (relatedProducts.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.all(defaultPadding),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    "You may also need",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: relatedProducts.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(
                        left: defaultPadding,
                        right: index == relatedProducts.length - 1
                            ? defaultPadding
                            : 0,
                      ),
                      child: ProductCard(
                        image: relatedProducts[index].image,
                        title: relatedProducts[index].title,
                        brandName: relatedProducts[index].brandName,
                        price: relatedProducts[index].price,
                        priceAfetDiscount:
                            relatedProducts[index].priceAfetDiscount,
                        dicountpercent: relatedProducts[index].dicountpercent,
                        onAddToCart: () => addProductToCartFromCard(
                          context,
                          relatedProducts[index],
                        ),
                        press: () {
                          Navigator.pushReplacementNamed(
                            context,
                            productDetailsScreenRoute,
                            arguments: relatedProducts[index],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: defaultPadding)),
          ],
        ),
      ),
    );
  }
}

class _DeliveryInformationSheet extends StatelessWidget {
  const _DeliveryInformationSheet();

  @override
  Widget build(BuildContext context) {
    final sections = const [
      (
        heading: "One-day delivery",
        body:
            "Orders inside Solapur city are usually packed quickly and delivered within 1 day on eligible orders.",
      ),
      (
        heading: "Cash on delivery",
        body:
            "You can place your order now and pay at your doorstep, or choose online payment during checkout.",
      ),
      (
        heading: "Before checkout",
        body:
            "Delivery is currently available only for Solapur city pincodes, so please add a serviceable address before ordering.",
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Delivery information",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          for (final section in sections) ...[
            Text(
              section.heading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(section.body),
            const SizedBox(height: defaultPadding),
          ],
        ],
      ),
    );
  }
}
