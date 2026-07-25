import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/core/utils/auth_required.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/models/product_option_model.dart';
import 'package:shop/screens/product/views/added_to_cart_message_screen.dart';

import '../../../constants.dart';
import 'components/product_quantity.dart';
import 'components/unit_price.dart';

class ProductBuyNowScreen extends StatefulWidget {
  const ProductBuyNowScreen({super.key, required this.product});

  final ProductModel product;

  @override
  State<ProductBuyNowScreen> createState() => _ProductBuyNowScreenState();
}

class _ProductBuyNowScreenState extends State<ProductBuyNowScreen> {
  int _quantity = 1;
  late ProductOptionModel? _selectedOption;

  double get _unitPrice =>
      _selectedOption?.effectivePrice ??
      widget.product.salePrice ??
      widget.product.price;

  int get _availableStock =>
      _selectedOption?.stockQuantity ?? widget.product.stockQuantity;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _selectedOption =
        product.packOptions
            .where((option) => option.stockQuantity > 0)
            .cast<ProductOptionModel?>()
            .firstOrNull ??
        product.defaultPackOption;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final totalPrice = _unitPrice * _quantity;
    final isBookmarked = context.watch<ProductProvider>().isBookmarked(
      product.id,
    );

    return Scaffold(
      bottomNavigationBar: CartButton(
        price: totalPrice,
        title: "Add to cart",
        subTitle: "Total price",
        press: () async {
          if (!requireAuthenticatedUser(
            context,
            message: 'Please log in to add items to your cart.',
          )) {
            return;
          }
          final messenger = ScaffoldMessenger.of(context);
          final cartProvider = context.read<CartProvider>();
          if (_availableStock <= 0) {
            messenger.showSnackBar(
              const SnackBar(content: Text('This pack is out of stock.')),
            );
            return;
          }
          final success = await cartProvider.addToCart(
            product,
            selectedOption: _selectedOption,
            quantity: _quantity,
          );
          if (!context.mounted) return;
          if (!success) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  cartProvider.errorMessage ??
                      'Unable to add this item to your cart right now.',
                ),
              ),
            );
            return;
          }
          if (!context.mounted) return;
          await customModalBottomSheet(
            context,
            height: 420,
            child: const AddedToCartMessageScreen(),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: defaultPadding / 2,
              vertical: defaultPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BackButton(),
                Expanded(
                  child: Text(
                    product.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (!requireAuthenticatedUser(
                      context,
                      message: 'Please log in to save products.',
                    )) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final productProvider = context.read<ProductProvider>();
                    final success = await productProvider.toggleBookmark(
                      product,
                    );
                    if (!context.mounted || success) return;
                    messenger.showSnackBar(
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
                          : Theme.of(context).textTheme.bodyLarge!.color!,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: defaultPadding,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.05,
                      child: NetworkImageWithLoader(product.imageUrl),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(defaultPadding),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: UnitPrice(
                                price: _selectedOption?.price ?? product.price,
                                priceAfterDiscount:
                                    _selectedOption?.salePrice ??
                                    product.salePrice,
                              ),
                            ),
                            ProductQuantity(
                              numOfItem: _quantity,
                              onIncrement: () {
                                if (_quantity >= _availableStock) return;
                                setState(() {
                                  _quantity += 1;
                                });
                              },
                              onDecrement: () {
                                if (_quantity == 1) return;
                                setState(() {
                                  _quantity -= 1;
                                });
                              },
                            ),
                          ],
                        ),
                        if (product.hasPackOptions) ...[
                          const SizedBox(height: defaultPadding),
                          Text(
                            'Pack size',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: defaultPadding / 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: product.packOptions.map((option) {
                              final isSelected =
                                  option.id == _selectedOption?.id;
                              final isDisabled = option.stockQuantity <= 0;
                              return ChoiceChip(
                                label: Text(
                                  isDisabled
                                      ? '${option.label} (Out of stock)'
                                      : option.label,
                                ),
                                selected: isSelected,
                                onSelected: isDisabled
                                    ? null
                                    : (_) {
                                        setState(() {
                                          _selectedOption = option;
                                          if (_quantity >
                                              option.stockQuantity) {
                                            _quantity = option.stockQuantity;
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: defaultPadding / 2),
                        Text(
                          _availableStock > 0
                              ? 'Available stock: $_availableStock'
                              : 'Currently unavailable',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider()),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.categoryName.isEmpty
                              ? "Product summary"
                              : product.categoryName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: defaultPadding / 2),
                        if (product.description.isNotEmpty) ...[
                          Text(product.description),
                          const SizedBox(height: defaultPadding),
                        ],
                        Text(
                          "Delivery support",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: defaultPadding / 2),
                        const Text(
                          "One-day delivery is available in Solapur city. Choose your pack, add it to cart, and we will take care of the rest.",
                        ),
                        const SizedBox(height: defaultPadding),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(defaultPadding),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(defaultBorderRadious),
                            ),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FriendlyDeliveryPoint(
                                icon: Icons.bolt_rounded,
                                text:
                                    'One-day delivery across eligible Solapur orders',
                              ),
                              SizedBox(height: 10),
                              _FriendlyDeliveryPoint(
                                icon: Icons.payments_outlined,
                                text:
                                    'Cash on delivery and online payment available',
                              ),
                              SizedBox(height: 10),
                              _FriendlyDeliveryPoint(
                                icon: Icons.favorite_border_rounded,
                                text:
                                    'A simple, customer-friendly checkout experience',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: defaultPadding),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendlyDeliveryPoint extends StatelessWidget {
  const _FriendlyDeliveryPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
