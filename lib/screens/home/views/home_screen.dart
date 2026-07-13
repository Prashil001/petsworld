import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/home_banner_card.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/core/utils/cart_actions.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/core/widgets/section_empty_state.dart';
import 'package:shop/models/category_model.dart';
import 'package:shop/models/coupon_model.dart';
import 'package:shop/models/home_banner_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenDiscover, this.onOpenCategory});

  final VoidCallback? onOpenDiscover;
  final ValueChanged<String>? onOpenCategory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _bannerController = PageController(
    viewportFraction: 0.99,
  );
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final allCategories = productProvider.discoverCategories;
    const petTypeIds = {'dogs', 'cats', 'dog', 'cat'};
    final categories = allCategories.where((c) {
      final t = c.title.toLowerCase().trim();
      final id = c.id.toLowerCase().trim();
      return petTypeIds.contains(t) || petTypeIds.contains(id);
    }).toList();
    final flashSaleProducts = productProvider.flashSaleProducts;
    final bestSellers = productProvider.popularProducts;
    final newArrivals = productProvider.newArrivals;
    final allProducts = productProvider.catalogProducts;
    final banners = productProvider.homeBanners;
    final homeSections = productProvider.homeSections;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final everythingEmpty =
        allCategories.isEmpty &&
        flashSaleProducts.isEmpty &&
        bestSellers.isEmpty &&
        newArrivals.isEmpty &&
        allProducts.isEmpty &&
        banners.isEmpty &&
        homeSections.isEmpty;
    // Show loader when Firebase is actively loading OR before loadInitialData()
    // has been called (isLoading=false but no data yet).
    final isInitialLoading = productProvider.isLoading || everythingEmpty;

    _syncBannerAutoplay(banners.length);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF0C1017),
                  Color(0xFF151B24),
                  Color(0xFF1B202A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: isInitialLoading
          ? const AppLoadingIndicator(message: 'Loading your pet store...')
          : CustomScrollView(
              slivers: <Widget>[
                // ── Search + Cart ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      defaultPadding,
                      defaultPadding,
                      defaultPadding,
                      defaultPadding,
                    ),
                    child: _SearchStrip(
                      onOpenCart: () =>
                          Navigator.pushNamed(context, cartScreenRoute),
                    ),
                  ),
                ),

                // ── Banner carousel ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      defaultPadding,
                      0,
                      defaultPadding,
                      defaultPadding,
                    ),
                    child: const _DeliveryHighlightCard(),
                  ),
                ),
                if (banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        defaultPadding,
                        0,
                        defaultPadding,
                        defaultPadding * 1.5,
                      ),
                      child: _BannerCarousel(
                        banners: banners,
                        controller: _bannerController,
                        currentIndex: _currentBannerIndex,
                        onPageChanged: (index) {
                          if (_currentBannerIndex == index) return;
                          setState(() => _currentBannerIndex = index);
                        },
                        onTapBanner: (banner) =>
                            _handleBannerTap(context, banner),
                      ),
                    ),
                  ),

                for (final section in homeSections)
                  if (productProvider
                      .productsForHomeSection(section)
                      .isNotEmpty)
                    SliverToBoxAdapter(
                      child: _ProductRailSection(
                        title: section.title,
                        leading: const Icon(
                          Icons.local_offer_outlined,
                          color: accentColor,
                          size: 18,
                        ),
                        badge: section.hasSectionDiscount
                            ? section.sectionDiscountType ==
                                      CouponDiscountType.flatAmount
                                  ? 'SAVE Rs ${section.sectionDiscountValue?.toStringAsFixed(0) ?? '0'}'
                                  : '${section.sectionDiscountValue?.toStringAsFixed(0) ?? '0'}% OFF'
                            : null,
                        badgeColor: dealBadgeBg,
                        badgeTextColor: dealBadgeText,
                        actionText: 'Shop all',
                        products: productProvider.productsForHomeSection(
                          section,
                        ),
                        onTapAction: () => _openDiscover(context),
                      ),
                    ),

                // ── Shop by pet ────────────────────────────────────────────────
                if (categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        defaultPadding,
                        0,
                        defaultPadding,
                        defaultPadding * 1.5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Minimal section label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Shop by pet',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              GestureDetector(
                                onTap: () => _openDiscover(context),
                                child: Text(
                                  'See all',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 152,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                return _CategoryAvatarItem(
                                  category: category,
                                  onTap: () =>
                                      _openCategory(context, category.title),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── New arrivals ───────────────────────────────────────────────
                if (newArrivals.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ProductRailSection(
                      title: 'New arrivals',
                      leading: const Icon(
                        Icons.auto_awesome_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                      actionText: 'See all',
                      products: newArrivals,
                      onTapAction: () => _openDiscover(context),
                    ),
                  ),

                // ── Deals of the week ──────────────────────────────────────────
                if (flashSaleProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ProductRailSection(
                      title: 'Deals of the week',
                      leading: const Icon(
                        Icons.local_fire_department_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                      badge: 'HOT',
                      badgeColor: dealBadgeBg,
                      badgeTextColor: dealBadgeText,
                      actionText: 'View deals',
                      products: flashSaleProducts,
                      onTapAction: () => _openDiscover(context),
                    ),
                  ),

                // ── Best sellers ───────────────────────────────────────────────
                if (bestSellers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ProductRailSection(
                      title: 'Best sellers',
                      leading: const Icon(
                        Icons.workspace_premium_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                      actionText: 'Shop now',
                      products: bestSellers,
                      onTapAction: () => _openDiscover(context),
                    ),
                  ),

                // ── Everything in store ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      defaultPadding,
                      defaultPadding / 2,
                      defaultPadding,
                      defaultPadding * 0.75,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Everything in store',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (!productProvider.isLoading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Text(
                              '${allProducts.length}${productProvider.hasMoreProducts ? '+' : ''} items',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (allProducts.isEmpty)
                  const SliverToBoxAdapter(
                    child: SectionEmptyState(
                      title: 'No products yet',
                      message:
                          'Add products in the admin panel and they will appear here automatically.',
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            defaultPadding,
                            0,
                            defaultPadding,
                            defaultPadding,
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: defaultPadding,
                                  crossAxisSpacing: defaultPadding,
                                  childAspectRatio: 0.7,
                                ),
                            itemCount: allProducts.length > 6
                                ? 6
                                : allProducts.length,
                            itemBuilder: (context, index) {
                              final product = allProducts[index];
                              return ProductCard(
                                image: product.image,
                                brandName: product.brandName,
                                title: product.title,
                                price: product.price,
                                priceAfetDiscount: product.priceAfetDiscount,
                                dicountpercent: product.dicountpercent,
                                isSaved: productProvider.isBookmarked(
                                  product.id,
                                ),
                                onToggleSaved: () {
                                  context
                                      .read<ProductProvider>()
                                      .toggleBookmark(product);
                                },
                                onAddToCart: () =>
                                    addProductToCartFromCard(context, product),
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
                        if (allProducts.length > 6)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              defaultPadding,
                              0,
                              defaultPadding,
                              defaultPadding * 1.5,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _openDiscover(context),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'View More',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _syncBannerAutoplay(int bannerCount) {
    if (bannerCount <= 1) {
      _bannerTimer?.cancel();
      _bannerTimer = null;
      return;
    }
    if (_bannerTimer != null) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerController.hasClients) return;
      final nextPage = (_currentBannerIndex + 1) % bannerCount;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleBannerTap(BuildContext context, HomeBannerModel banner) {
    final actionCategory = (banner.actionCategory ?? '').trim();
    if (actionCategory.isNotEmpty) {
      _openCategory(context, actionCategory);
      return;
    }
    _openDiscover(context);
  }

  void _openDiscover(BuildContext context) {
    if (widget.onOpenDiscover != null) {
      widget.onOpenDiscover!.call();
      return;
    }
    Navigator.pushNamed(context, discoverScreenRoute);
  }

  void _openCategory(BuildContext context, String categoryTitle) {
    if (widget.onOpenCategory != null) {
      widget.onOpenCategory!.call(categoryTitle);
      return;
    }
    Navigator.pushNamed(
      context,
      categoryProductsScreenRoute,
      arguments: categoryTitle,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH STRIP  — with integrated cart button
// ─────────────────────────────────────────────────────────────────────────────
class _SearchStrip extends StatelessWidget {
  const _SearchStrip({required this.onOpenCart});

  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartProvider = context.watch<CartProvider>();

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            onTap: () => Navigator.pushNamed(context, searchScreenRoute),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF171D27)
                    : const Color(0xFFFFFCF8),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C3442)
                      : const Color(0xFFE5D7C4),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: const Color(0xFFB78A54).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : const Color(0xFF9E8672),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search food, treats, toys, care...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.white30
                            : const Color(0xFF9E8672),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Cart button
        _CartActionButton(count: cartProvider.totalItems, onTap: onOpenCart),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _CartActionButton extends StatelessWidget {
  const _CartActionButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171D27) : const Color(0xFFFFFCF8),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2C3442)
                    : const Color(0xFFE5D7C4),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: const Color(0xFFB78A54).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: const Icon(Icons.shopping_bag_outlined, size: 20),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: errorColor,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER CAROUSEL  — clean, no surrounding text
// ─────────────────────────────────────────────────────────────────────────────
class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel({
    required this.banners,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTapBanner,
  });

  final List<HomeBannerModel> banners;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<HomeBannerModel> onTapBanner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 248,
          child: PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: HomeBannerCard(
                  banner: banner,
                  onTap: () => onTapBanner(banner),
                ),
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: currentIndex == index ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: currentIndex == index
                      ? primaryColor
                      : Theme.of(context).dividerColor.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY AVATAR ITEM  — compact, image + label only
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryAvatarItem extends StatelessWidget {
  const _CategoryAvatarItem({required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _categoryAccent(category.title);

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: SizedBox(
        width: 112,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF171D27)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            border: Border.all(
              color: isDark ? const Color(0xFF2A323F) : const Color(0xFFE7DBCD),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.26 : 0.18),
                      accent.withValues(alpha: 0.03),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: NetworkImageWithLoader(
                    (category.image ?? '').trim(),
                    fit: BoxFit.contain,
                    radius: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryAccent(String title) {
    switch (title.trim().toLowerCase()) {
      case 'dogs':
      case 'dog':
        return const Color(0xFFD5863E);
      case 'cats':
      case 'cat':
        return const Color(0xFF8E7AE6);
      default:
        return const Color(0xFF4D8C75);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT RAIL SECTION  — minimal header: icon + title + action
// ─────────────────────────────────────────────────────────────────────────────
class _ProductRailSection extends StatelessWidget {
  const _ProductRailSection({
    required this.title,
    required this.actionText,
    required this.products,
    required this.onTapAction,
    this.leading,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
  });

  final String title;
  final String actionText;
  final List<ProductModel> products;
  final VoidCallback onTapAction;
  final Widget? leading;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: defaultPadding * 1.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minimal header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              defaultPadding,
              0,
              defaultPadding,
              12,
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFFF4EAFD),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(999),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: badgeTextColor ?? primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: onTapAction,
                  child: Text(
                    actionText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Horizontal product list
          SizedBox(
            height: 268,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                final productProvider = context.watch<ProductProvider>();
                return SizedBox(
                  width: 164,
                  child: ProductCard(
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
                    onAddToCart: () =>
                        addProductToCartFromCard(context, product),
                    press: () {
                      Navigator.pushNamed(
                        context,
                        productDetailsScreenRoute,
                        arguments: product,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryHighlightCard extends StatelessWidget {
  const _DeliveryHighlightCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF2A234D), Color(0xFF171D27)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF9A7CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B61FF).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Same day delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fast doorstep delivery across Solapur city.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
