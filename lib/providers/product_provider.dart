import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shop/models/category_model.dart';
import 'package:shop/models/coupon_model.dart';
import 'package:shop/models/delivery_settings_model.dart';
import 'package:shop/models/home_banner_model.dart';
import 'package:shop/models/home_section_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/category_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/user_data_repository.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({
    required ProductRepository productRepository,
    required CategoryRepository categoryRepository,
    required UserDataRepository userDataRepository,
  }) : _productRepository = productRepository,
       _categoryRepository = categoryRepository,
       _userDataRepository = userDataRepository;

  final ProductRepository _productRepository;
  final CategoryRepository _categoryRepository;
  final UserDataRepository _userDataRepository;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<ProductModel> _catalogProducts = const <ProductModel>[];
  List<ProductModel> _featuredProducts = const <ProductModel>[];
  List<HomeBannerModel> _homeBanners = const <HomeBannerModel>[];
  List<HomeSectionModel> _homeSections = const <HomeSectionModel>[];
  DeliverySettingsModel _deliverySettings = const DeliverySettingsModel();
  final Map<String, List<ProductModel>> _homeSectionProducts =
      <String, List<ProductModel>>{};
  static const List<CategoryModel> _fallbackCategories = <CategoryModel>[
    CategoryModel(id: 'Dog', title: 'Dog'),
    CategoryModel(id: 'Cat', title: 'Cat'),
    CategoryModel(id: 'Grooming', title: 'Grooming'),
    CategoryModel(id: 'Accessories', title: 'Accessories'),
  ];
  List<CategoryModel> _discoverCategories = _fallbackCategories;
  final Set<String> _bookmarkedProductIds = <String>{};
  String? _userId;

  // Pagination state
  static const int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  String? _currentCategoryFilter;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  List<ProductModel> get catalogProducts => _catalogProducts;
  List<ProductModel> get featuredProducts => _featuredProducts;
  List<HomeBannerModel> get homeBanners => _homeBanners;
  List<HomeSectionModel> get homeSections => _homeSections;
  DeliverySettingsModel get deliverySettings => _deliverySettings;
  bool get hasMoreProducts => _hasMore;
  List<ProductModel> get popularProducts =>
      _catalogProducts.where((product) => product.isPopular).toList();
  List<ProductModel> get flashSaleProducts => _catalogProducts
      .where(
        (product) =>
            (product.dicountpercent ?? 0) > 0 ||
            (product.salePrice != null && product.salePrice! < product.price),
      )
      .toList();
  List<ProductModel> get bestSellerProducts => popularProducts;
  List<ProductModel> get mostPopularProducts => popularProducts;
  List<ProductModel> get newArrivals =>
      _catalogProducts.where((product) => product.isNewArrival).toList();

  List<ProductModel> get bookmarkedProducts => _catalogProducts
      .where((product) => _bookmarkedProductIds.contains(product.id))
      .toList();
  List<CategoryModel> get discoverCategories => _discoverCategories;
  int get bookmarkedCount => _bookmarkedProductIds.length;

  bool isBookmarked(String productId) =>
      _bookmarkedProductIds.contains(productId);

  Future<void> syncUserData(String? userId) async {
    if (_userId == userId) {
      return;
    }

    _userId = userId;
    _bookmarkedProductIds.clear();
    notifyListeners();

    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final savedIds = await _userDataRepository.getSavedProductIds(userId);
      _bookmarkedProductIds
        ..clear()
        ..addAll(savedIds);
    } catch (error) {
      _errorMessage = error.toString();
    }

    notifyListeners();
  }

  Future<bool> toggleBookmark(ProductModel product) async {
    if (_userId == null || _userId!.isEmpty) {
      _errorMessage = 'Please log in to save products.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    final previousBookmarkIds = Set<String>.from(_bookmarkedProductIds);
    final previousCatalog = List<ProductModel>.from(_catalogProducts);
    if (_bookmarkedProductIds.contains(product.id)) {
      _bookmarkedProductIds.remove(product.id);
    } else {
      _bookmarkedProductIds.add(product.id);
      if (_catalogProducts.every((item) => item.id != product.id)) {
        _catalogProducts = <ProductModel>[product, ..._catalogProducts];
      }
    }

    notifyListeners();

    try {
      if (previousBookmarkIds.contains(product.id)) {
        await _userDataRepository.removeSavedProduct(
          userId: _userId!,
          productId: product.id,
        );
      } else {
        await _userDataRepository.saveProduct(
          userId: _userId!,
          product: product,
        );
      }
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      _bookmarkedProductIds
        ..clear()
        ..addAll(previousBookmarkIds);
      _catalogProducts = previousCatalog;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    _lastDocument = null;
    _hasMore = true;
    _currentCategoryFilter = null;
    // Deferred: this can run synchronously during the provider's own lazy
    // `create`, before its InheritedElement finishes building. Notifying
    // immediately would call markNeedsBuild on a widget still under
    // construction.
    Future.microtask(notifyListeners);

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _productRepository.getCatalogProducts(
          limit: _pageSize,
          startAfter: null,
        ),
        _productRepository.getFeaturedProducts(),
        _productRepository.getHomeBanners(),
        _productRepository.getHomeSections(),
        _productRepository.getDeliverySettings(),
        _categoryRepository.getDiscoverCategories(),
      ]);

      final catalogResult = results[0] as PaginatedResult<ProductModel>;
      _catalogProducts = catalogResult.items;
      _lastDocument = catalogResult.lastDocument;
      _featuredProducts = results[1] as List<ProductModel>;
      final loadedBanners = results[2] as List<HomeBannerModel>;
      final loadedSections = results[3] as List<HomeSectionModel>;
      _deliverySettings = results[4] as DeliverySettingsModel;
      final loadedCategories = results[5] as List<CategoryModel>;
      _homeBanners = loadedBanners.where((banner) => banner.isActive).toList();
      _homeSections = loadedSections;
      await _loadSectionProducts(loadedSections);
      _discoverCategories = loadedCategories.isEmpty
          ? _fallbackCategories
          : loadedCategories;

      _hasMore = _catalogProducts.length >= _pageSize;
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProductsByCategory(String category) async {
    _isLoading = true;
    _errorMessage = null;
    _lastDocument = null;
    _hasMore = true;
    _currentCategoryFilter = category;
    notifyListeners();

    try {
      final result = await _productRepository.getCatalogProducts(
        category: category,
        limit: _pageSize,
        startAfter: null,
      );
      _catalogProducts = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = _catalogProducts.length >= _pageSize;
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) {
      return;
    }

    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _productRepository.getCatalogProducts(
        category: _currentCategoryFilter,
        limit: _pageSize,
        startAfter: _lastDocument,
      );
      _catalogProducts = [..._catalogProducts, ...result.items];
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= _pageSize;
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<List<ProductModel>> searchProducts(String query, {int limit = 20}) {
    return _productRepository.searchProducts(query: query, limit: limit);
  }

  List<ProductModel> searchInCatalog(
    String query, {
    List<ProductModel>? source,
  }) {
    final normalized = query.trim().toLowerCase();
    final items = source ?? _catalogProducts;
    if (normalized.isEmpty) {
      return items;
    }

    return items.where((product) {
      final name = product.name.toLowerCase();
      final category = product.category.toLowerCase();
      final description = product.description.toLowerCase();
      final brand = product.brandName.toLowerCase();
      return name.contains(normalized) ||
          category.contains(normalized) ||
          description.contains(normalized) ||
          brand.contains(normalized);
    }).toList();
  }

  List<ProductModel> productsForHomeSection(HomeSectionModel section) {
    final products = _homeSectionProducts[section.id] ?? const <ProductModel>[];
    return products
        .map((product) => _applySectionDiscount(product, section))
        .toList();
  }

  ProductModel productWithHomeSectionDiscount(
    ProductModel product,
    HomeSectionModel section,
  ) {
    return _applySectionDiscount(product, section);
  }

  ProductModel _applySectionDiscount(
    ProductModel product,
    HomeSectionModel section,
  ) {
    if (!section.hasSectionDiscount) return product;

    final basePrice = product.salePrice ?? product.price;
    final discountValue = section.sectionDiscountValue ?? 0;
    if (discountValue <= 0) return product;

    double computedSalePrice = basePrice;
    int? computedPercent;
    if (section.sectionDiscountType == CouponDiscountType.flatAmount) {
      computedSalePrice = (basePrice - discountValue).clamp(0, basePrice);
      computedPercent = product.price <= 0
          ? null
          : (((product.price - computedSalePrice) / product.price) * 100)
                .round();
    } else {
      computedSalePrice = basePrice * ((100 - discountValue) / 100);
      computedPercent = discountValue.round();
    }

    final effectiveSalePrice = product.salePrice == null
        ? computedSalePrice
        : computedSalePrice < product.salePrice!
        ? computedSalePrice
        : product.salePrice!;

    if (effectiveSalePrice >= product.price) return product;

    return product.copyWith(
      salePrice: effectiveSalePrice,
      discountPercent: computedPercent,
    );
  }

  Future<void> _loadSectionProducts(List<HomeSectionModel> sections) async {
    _homeSectionProducts.clear();
    final ids = sections
        .expand((section) => section.productIds)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    final loadedProducts = await _productRepository.getProductsByIds(ids);
    final productById = <String, ProductModel>{
      for (final product in loadedProducts) product.id: product,
    };

    for (final section in sections) {
      final mapped = section.productIds
          .map((id) => productById[id])
          .whereType<ProductModel>()
          .toList();
      _homeSectionProducts[section.id] = mapped;
    }
  }
}
