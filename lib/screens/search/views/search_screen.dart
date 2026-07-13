import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/core/utils/cart_actions.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;
  String _query = '';
  bool _isSearching = false;
  List<ProductModel> _results = const <ProductModel>[];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: SearchForm(
                autofocus: true,
                onChanged: (value) => _onQueryChanged(value ?? ''),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                defaultPadding,
              ),
              child: Text(
                _query.isEmpty
                    ? 'Type at least 2 letters to search the catalog.'
                    : _isSearching
                    ? 'Searching...'
                    : '${_results.length} item${_results.length == 1 ? '' : 's'} found for "$_query".',
              ),
            ),
          ),
          if (_query.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Text(
                  'Search runs on demand and does not load the full catalog here.',
                ),
              ),
            )
          else if (_isSearching)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppLoadingIndicator(message: 'Searching products...'),
            )
          else if (_results.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Text(
                  'No products matched this search. Try another keyword.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                defaultPadding,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: defaultPadding,
                  crossAxisSpacing: defaultPadding,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = _results[index];
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
                }, childCount: _results.length),
              ),
            ),
        ],
      ),
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final nextQuery = value.trim();

    setState(() {
      _query = nextQuery;
      if (_query.isEmpty || _query.length < 2) {
        _isSearching = false;
        _results = const <ProductModel>[];
      }
    });

    if (nextQuery.length < 2) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = true;
      });

      final results = await context.read<ProductProvider>().searchProducts(
        nextQuery,
        limit: 24,
      );
      if (!mounted || _query != nextQuery) {
        return;
      }

      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }
}
