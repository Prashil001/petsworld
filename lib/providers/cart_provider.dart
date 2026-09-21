import 'package:flutter/foundation.dart';

import 'package:shop/models/cart_pricing_summary_model.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/coupon_model.dart';
import 'package:shop/models/delivery_settings_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/models/product_option_model.dart';
import 'package:shop/repositories/coupon_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/storefront_repository.dart';
import 'package:shop/repositories/user_data_repository.dart';

class CartProvider extends ChangeNotifier {
  CartProvider({
    required UserDataRepository userDataRepository,
    required CouponRepository couponRepository,
    required ProductRepository productRepository,
    required StorefrontRepository storefrontRepository,
  }) : _userDataRepository = userDataRepository,
       _couponRepository = couponRepository,
       _productRepository = productRepository,
       _storefrontRepository = storefrontRepository;

  final UserDataRepository _userDataRepository;
  final CouponRepository _couponRepository;
  final ProductRepository _productRepository;
  final StorefrontRepository _storefrontRepository;

  final List<CartItemModel> _items = <CartItemModel>[];
  String? _userId;
  bool _isLoading = false;
  bool _isApplyingCoupon = false;
  String? _errorMessage;
  String? _couponMessage;
  CouponModel? _appliedCoupon;
  DeliverySettingsModel _deliverySettings = const DeliverySettingsModel();

  List<CartItemModel> get items => List<CartItemModel>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isApplyingCoupon => _isApplyingCoupon;
  String? get errorMessage => _errorMessage;
  String? get couponMessage => _couponMessage;
  CouponModel? get appliedCoupon => _appliedCoupon;
  DeliverySettingsModel get deliverySettings => _deliverySettings;

  int get totalItems =>
      _items.fold<int>(0, (total, item) => total + item.quantity);

  double get subtotal =>
      _items.fold<double>(0, (total, item) => total + item.totalPrice);

  double get originalSubtotal => _items.fold<double>(
    0,
    (total, item) =>
        total + ((item.originalUnitPrice ?? item.unitPrice) * item.quantity),
  );

  double get productDiscount =>
      (originalSubtotal - subtotal).clamp(0.0, double.infinity).toDouble();

  bool get hasOutOfStockItems =>
      _items.any((item) => item.isOutOfStock || item.hasExceededStock);

  List<CartItemModel> get invalidStockItems =>
      _items.where((item) => item.isOutOfStock || item.hasExceededStock).toList();

  CartPricingSummaryModel get pricing {
    final couponDiscount = _calculateCouponDiscount(
      coupon: _appliedCoupon,
      subtotalValue: subtotal,
    );
    final deliveryCharge = _items.isEmpty
        ? 0.0
        : subtotal >= _deliverySettings.freeDeliveryThreshold
        ? 0.0
        : _deliverySettings.deliveryFee;
    final total = (subtotal - couponDiscount + deliveryCharge)
        .clamp(0.0, double.infinity)
        .toDouble();
    return CartPricingSummaryModel(
      subtotal: subtotal,
      originalSubtotal: originalSubtotal,
      productDiscount: productDiscount,
      couponDiscount: couponDiscount,
      deliveryCharge: deliveryCharge,
      total: total,
      freeDeliveryThreshold: _deliverySettings.freeDeliveryThreshold,
    );
  }

  Future<void> initialize() async {
    await loadPricingConfig();
  }

  Future<void> loadPricingConfig() async {
    try {
      _deliverySettings = await _storefrontRepository.getDeliverySettings();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> syncForUser(String? userId) async {
    if (_userId == userId) {
      return;
    }

    _userId = userId;
    _items.clear();
    _appliedCoupon = null;
    _couponMessage = null;
    notifyListeners();

    if (userId == null || userId.isEmpty) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final storedItems = await _userDataRepository.getCartItems(userId);
      _items
        ..clear()
        ..addAll(storedItems);
      await _refreshCartProductSnapshots();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      _refreshCouponState();
    }
  }

  Future<bool> addToCart(
    ProductModel product, {
    ProductOptionModel? selectedOption,
    int quantity = 1,
  }) async {
    final resolvedOption = selectedOption ?? product.defaultPackOption;
    final optionId = resolvedOption?.id ?? '';
    final optionLabel = resolvedOption?.label ?? '';
    final unitPrice =
        resolvedOption?.effectivePrice ?? product.salePrice ?? product.price;
    final originalUnitPrice = resolvedOption?.price ?? product.price;
    final itemId =
        '${product.id}::${optionId.trim().isEmpty ? 'default' : optionId.trim()}';

    final availableStock = resolvedOption?.stockQuantity ?? product.stockQuantity;
    if (availableStock <= 0) {
      _errorMessage = 'This item is currently out of stock.';
      notifyListeners();
      return false;
    }

    final existingIndex = _items.indexWhere((item) => item.id == itemId);
    final currentQty = existingIndex >= 0 ? _items[existingIndex].quantity : 0;
    if (currentQty + quantity > availableStock) {
      _errorMessage = 'Only $availableStock item(s) available in stock.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    if (existingIndex >= 0) {
      final existingItem = _items[existingIndex];
      _items[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
        unitPrice: unitPrice,
        originalUnitPrice: originalUnitPrice,
        product: product,
      );
    } else {
      _items.add(
        CartItemModel(
          product: product,
          selectedOptionId: optionId,
          selectedOptionLabel: optionLabel,
          unitPrice: unitPrice,
          originalUnitPrice: originalUnitPrice,
          quantity: quantity,
        ),
      );
    }

    notifyListeners();
    try {
      await _persistCartItem(itemId);
      _refreshCouponState();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity(
    String cartItemId,
    int quantity,
  ) async {
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index < 0) {
      return false;
    }

    if (quantity <= 0) {
      return removeFromCart(cartItemId);
    }

    final item = _items[index];
    final availableStock = item.availableStock;
    if (quantity > availableStock) {
      _errorMessage = 'Only $availableStock item(s) available in stock.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _items[index] = item.copyWith(quantity: quantity);
    notifyListeners();
    try {
      await _persistCartItem(cartItemId);
      _refreshCouponState();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFromCart(String cartItemId) async {
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index < 0) {
      return false;
    }

    _errorMessage = null;
    _items.removeAt(index);
    notifyListeners();
    try {
      if (_userId != null && _userId!.isNotEmpty) {
        await _userDataRepository.removeCartItem(
          userId: _userId!,
          cartItemId: cartItemId,
        );
      }
      _refreshCouponState();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> clear() async {
    _items.clear();
    _errorMessage = null;
    notifyListeners();
    try {
      if (_userId != null && _userId!.isNotEmpty) {
        await _userDataRepository.clearCart(_userId!);
      }
      clearAppliedCoupon(notify: false);
      _refreshCouponState();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _persistCartItem(String cartItemId) async {
    if (_userId == null || _userId!.isEmpty) {
      return;
    }
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      await _userDataRepository.upsertCartItem(
        userId: _userId!,
        item: _items[index],
      );
    }
  }

  Future<bool> applyCoupon(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      _couponMessage = 'Enter a coupon code.';
      notifyListeners();
      return false;
    }

    _isApplyingCoupon = true;
    _couponMessage = null;
    notifyListeners();

    try {
      await _refreshCartProductSnapshots();
      final coupon = await _couponRepository.getCouponByCode(normalized);
      final validationMessage = _validateCoupon(coupon);
      if (validationMessage != null) {
        _appliedCoupon = null;
        _couponMessage = validationMessage;
        return false;
      }

      _appliedCoupon = coupon;
      _couponMessage = 'Coupon applied successfully.';
      return true;
    } catch (_) {
      _couponMessage = 'Unable to validate this coupon right now.';
      return false;
    } finally {
      _isApplyingCoupon = false;
      notifyListeners();
    }
  }

  void clearAppliedCoupon({bool notify = true}) {
    _appliedCoupon = null;
    _couponMessage = null;
    if (notify) {
      notifyListeners();
    }
  }

  void markCouponUsed() {
    if (_appliedCoupon == null) return;
    _couponRepository.incrementCouponUsage(_appliedCoupon!.id);
  }

  void _refreshCouponState() {
    if (_appliedCoupon == null) {
      notifyListeners();
      return;
    }

    final validationMessage = _validateCoupon(_appliedCoupon);
    if (validationMessage != null) {
      _appliedCoupon = null;
      _couponMessage = validationMessage;
    }
    notifyListeners();
  }

  String? _validateCoupon(CouponModel? coupon) {
    if (coupon == null) {
      return 'Invalid coupon code.';
    }
    if (!coupon.isActive) {
      return 'This coupon is inactive.';
    }
    if (coupon.isExpired) {
      return 'This coupon has expired.';
    }
    if (coupon.hasReachedUsageLimit) {
      return 'This coupon has reached its usage limit.';
    }
    if (subtotal < coupon.minCartValue) {
      return 'Coupon is valid only on carts above Rs ${coupon.minCartValue.toStringAsFixed(0)}.';
    }

    final applicableAmount = _applicableSubtotalForCoupon(coupon);
    if (applicableAmount <= 0) {
      return 'This coupon is not applicable to the products in your cart.';
    }
    return null;
  }

  double _calculateCouponDiscount({
    required CouponModel? coupon,
    required double subtotalValue,
  }) {
    if (coupon == null) return 0;
    if (_validateCoupon(coupon) != null) return 0;

    final applicableSubtotal = _applicableSubtotalForCoupon(coupon);
    if (applicableSubtotal <= 0) return 0;

    if (coupon.discountType == CouponDiscountType.flatAmount) {
      return coupon.discountValue.clamp(0, applicableSubtotal).toDouble();
    }

    return (applicableSubtotal * (coupon.discountValue / 100))
        .clamp(0, subtotalValue)
        .toDouble();
  }

  double _applicableSubtotalForCoupon(CouponModel coupon) {
    if (coupon.appliesToAll) return subtotal;

    return _items.fold<double>(0, (total, item) {
      final inProductScope = coupon.applicableProductIds.contains(
        item.product.id,
      );
      final inCategoryScope = coupon.applicableCategoryIds.any(
        (categoryId) => _couponCategoryMatchesProduct(
          categoryId: categoryId,
          productCategory: item.product.category,
        ),
      );
      if (inProductScope || inCategoryScope) {
        return total + item.totalPrice;
      }
      return total;
    });
  }

  Future<void> refreshCartStock() async {
    await _refreshCartProductSnapshots();
  }

  Future<void> _refreshCartProductSnapshots() async {
    if (_items.isEmpty) {
      return;
    }

    final productIds = _items
        .map((item) => item.product.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (productIds.isEmpty) {
      return;
    }

    try {
      final latestProducts = await _productRepository.getProductsByIds(productIds);
      if (latestProducts.isEmpty) {
        return;
      }

      final productById = <String, ProductModel>{
        for (final product in latestProducts) product.id: product,
      };

      var changed = false;
      for (var index = 0; index < _items.length; index += 1) {
        final currentItem = _items[index];
        final latestProduct = productById[currentItem.product.id];
        if (latestProduct == null) {
          if (currentItem.product.isActive || currentItem.product.stockQuantity > 0) {
            _items[index] = currentItem.copyWith(
              product: currentItem.product.copyWith(
                isActive: false,
                stockQuantity: 0,
              ),
            );
            changed = true;
          }
          continue;
        }

        final optionId = currentItem.selectedOptionId.trim();
        ProductOptionModel? latestOption;
        if (optionId.isNotEmpty && optionId != 'default') {
          for (final opt in latestProduct.packOptions) {
            if (opt.id == optionId) {
              latestOption = opt;
              break;
            }
          }
        }

        final newUnitPrice =
            latestOption?.effectivePrice ?? latestProduct.salePrice ?? latestProduct.price;
        final newOriginalPrice = latestOption?.price ?? latestProduct.price;

        if (latestProduct.category != currentItem.product.category ||
            latestProduct.name != currentItem.product.name ||
            latestProduct.imageUrl != currentItem.product.imageUrl ||
            latestProduct.salePrice != currentItem.product.salePrice ||
            latestProduct.price != currentItem.product.price ||
            latestProduct.stockQuantity != currentItem.product.stockQuantity ||
            latestProduct.isActive != currentItem.product.isActive ||
            currentItem.unitPrice != newUnitPrice ||
            currentItem.originalUnitPrice != newOriginalPrice) {
          _items[index] = currentItem.copyWith(
            product: latestProduct,
            unitPrice: newUnitPrice,
            originalUnitPrice: newOriginalPrice,
          );
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
        if (_userId != null && _userId!.isNotEmpty) {
          for (final item in _items) {
            await _userDataRepository.upsertCartItem(
              userId: _userId!,
              item: item,
            );
          }
        }
      }
    } catch (_) {
      // Keep checkout usable even if product refresh fails.
    }
  }

  bool _couponCategoryMatchesProduct({
    required String categoryId,
    required String productCategory,
  }) {
    final normalizedProductCategory = _normalizeCategoryKey(productCategory);
    final productSegments = productCategory
        .split('>')
        .map(_normalizeCategoryKey)
        .where((item) => item.isNotEmpty)
        .toList();
    final categoryVariants = _categoryMatchVariants(categoryId);

    if (categoryVariants.isEmpty || normalizedProductCategory.isEmpty) {
      return false;
    }

    for (final variant in categoryVariants) {
      if (productSegments.contains(variant)) {
        return true;
      }
      if (normalizedProductCategory == variant) {
        return true;
      }
      if (normalizedProductCategory.startsWith('$variant ') ||
          normalizedProductCategory.contains(' $variant ') ||
          normalizedProductCategory.endsWith(' $variant')) {
        return true;
      }
      if (_tokensAppearInOrder(
        pattern: variant.split(' '),
        target: normalizedProductCategory.split(' '),
      )) {
        return true;
      }
    }

    return false;
  }

  String _normalizeCategoryKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('(all)', ' ')
        .replaceAll('/', ' ')
        .replaceAll('&', ' ')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _categoryMatchVariants(String categoryId) {
    final normalized = _normalizeCategoryKey(categoryId);
    if (normalized.isEmpty) {
      return const <String>{};
    }

    final variants = <String>{normalized};
    final words = normalized.split(' ');
    if (words.length > 1) {
      variants.add(words.skip(1).join(' '));
    }
    if (words.length > 1 && words.last == 'all') {
      variants.add(words.take(words.length - 1).join(' '));
      if (words.length > 2) {
        variants.add(words.skip(1).take(words.length - 2).join(' '));
      }
    }

    if (normalized.startsWith('dogs ')) {
      final tail = normalized.substring('dogs '.length);
      variants
        ..add(tail)
        ..add('dog $tail');
      if (tail.endsWith(' all')) {
        final tailWithoutAll = tail.substring(0, tail.length - ' all'.length);
        variants
          ..add(tailWithoutAll)
          ..add('dog $tailWithoutAll');
      }
      if (tail == 'food all') {
        variants
          ..add('dog food all')
          ..add('dog food');
      }
    }

    if (normalized.startsWith('cats ')) {
      final tail = normalized.substring('cats '.length);
      variants
        ..add(tail)
        ..add('cat $tail');
      if (tail.endsWith(' all')) {
        final tailWithoutAll = tail.substring(0, tail.length - ' all'.length);
        variants
          ..add(tailWithoutAll)
          ..add('cat $tailWithoutAll');
      }
      if (tail == 'food all') {
        variants
          ..add('cat food all')
          ..add('cat food');
      }
    }

    return variants.where((item) => item.trim().isNotEmpty).toSet();
  }

  bool _tokensAppearInOrder({
    required List<String> pattern,
    required List<String> target,
  }) {
    if (pattern.isEmpty) return false;
    var targetIndex = 0;
    for (final token in pattern) {
      var found = false;
      while (targetIndex < target.length) {
        if (target[targetIndex] == token) {
          found = true;
          targetIndex += 1;
          break;
        }
        targetIndex += 1;
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }
}
