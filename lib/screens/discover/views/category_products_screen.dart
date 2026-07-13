import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/core/utils/cart_actions.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/core/widgets/section_empty_state.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';

class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.categoryTitle,
    this.petType,
  });

  final String categoryTitle;
  final String? petType;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    context.read<ProductProvider>().loadProductsByCategory(
      widget.categoryTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.catalogProducts;
    final filteredProducts = products.where((product) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return product.title.toLowerCase().contains(query) ||
          product.brandName.toLowerCase().contains(query) ||
          product.categoryName.toLowerCase().contains(query);
    }).toList();
    final isInitialLoading = productProvider.isLoading && products.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryTitle.trim().isEmpty
              ? 'Category'
              : widget.categoryTitle,
        ),
      ),
      body: isInitialLoading
          ? const AppLoadingIndicator(message: 'Loading products...')
          : products.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: SectionEmptyState(
                  title: 'No products yet',
                  message:
                      'Products added to this category will appear here automatically.',
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      defaultPadding,
                      defaultPadding,
                      defaultPadding,
                      0,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search in this category',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  if (filteredProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: SectionEmptyState(
                        title: 'No matching products',
                        message:
                            'Try a different keyword to find products in this category.',
                      ),
                    )
                  else
                    GridView.builder(
                      padding: const EdgeInsets.all(defaultPadding),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: defaultPadding,
                            crossAxisSpacing: defaultPadding,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ProductCard(
                          image: product.image,
                          brandName: product.brandName,
                          title: product.title,
                          price: product.price,
                          priceAfetDiscount: product.priceAfetDiscount,
                          dicountpercent: product.dicountpercent,
                          isSaved: productProvider.isBookmarked(product.id),
                          onToggleSaved: () {
                            context.read<ProductProvider>().toggleBookmark(
                              product,
                            );
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
                  if (filteredProducts.isNotEmpty &&
                      productProvider.hasMoreProducts)
                    Padding(
                      padding: const EdgeInsets.all(defaultPadding),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: productProvider.isLoadingMore
                              ? null
                              : () => productProvider.loadMoreProducts(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: productProvider.isLoadingMore
                              ? const SizedBox(
                                  height: 22,
                                  width: 48,
                                  child: AppLoadingIndicator(
                                    size: 10,
                                    color: Colors.white,
                                    center: false,
                                  ),
                                )
                              : const Text(
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
    );
  }
}
