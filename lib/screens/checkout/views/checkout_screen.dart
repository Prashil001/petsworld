import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:shop/constants.dart';
import 'package:shop/core/config/payment_config.dart';
import 'package:shop/core/services/checkout_api_service.dart';
import 'package:shop/core/services/razorpay_checkout_service.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/models/address_model.dart';
import 'package:shop/models/app_user_model.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/order_delivery_address_model.dart';
import 'package:shop/models/order_item_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/models/order_payment_model.dart';
import 'package:shop/models/order_pricing_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/providers/address_provider.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/order_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/repositories/storefront_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/address/views/address_form_screen.dart';
import 'package:shop/screens/order/views/order_success_screen.dart';

enum _CheckoutPaymentMethod { razorpay, cod }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CheckoutApiService _checkoutApiService = CheckoutApiService();
  final RazorpayCheckoutService _razorpayService = RazorpayCheckoutService();
  final Random _random = Random();
  final TextEditingController _couponController = TextEditingController();

  bool _isProcessing = false;
  String? _activeRazorpayOrderId;
  OrderModel? _activeRazorpayDraftOrder;
  bool _razorpaySessionResolved = false;
  bool _isRefreshingPaymentConfig = false;
  _CheckoutPaymentMethod _selectedPaymentMethod =
      _CheckoutPaymentMethod.razorpay;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshPaymentConfig);
  }

  @override
  void dispose() {
    _couponController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final cartProvider = context.watch<CartProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final AppUserModel? user = authProvider.currentUser;
    final items = cartProvider.items;
    final selectedAddress = addressProvider.selectedAddress;
    final pricing = cartProvider.pricing;
    final onlinePaymentAvailable = isOnlinePaymentAvailable;

    if (!onlinePaymentAvailable &&
        _selectedPaymentMethod == _CheckoutPaymentMethod.razorpay) {
      _selectedPaymentMethod = _CheckoutPaymentMethod.cod;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Stack(
        children: [
          if (!authProvider.isAuthenticated)
            _SignedOutState(
              onSignIn: () => Navigator.pushNamed(context, logInScreenRoute),
            )
          else if (items.isEmpty)
            _EmptyCheckoutState(
              onContinueShopping: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  entryPointScreenRoute,
                  (route) => false,
                );
              },
            )
          else
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(defaultPadding),
                children: [
                  _SectionCard(
                    title: 'Cart items',
                    child: Column(
                      children: [
                        for (final item in items) ...[
                          _CheckoutItemTile(item: item),
                          if (item != items.last)
                            const Divider(height: defaultPadding * 1.5),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  _SectionCard(
                    title: 'Delivery address',
                    actionLabel: 'Manage',
                    onAction: () =>
                        Navigator.pushNamed(context, addressesScreenRoute),
                    child: addressProvider.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: AppLoadingIndicator(
                              size: 20,
                              message: 'Loading addresses...',
                            ),
                          )
                        : _AddressSection(
                            selectedAddress: selectedAddress,
                            addresses: addressProvider.addresses,
                            onSelect: (address) {
                              context
                                  .read<AddressProvider>()
                                  .selectAddressForCheckout(address.id);
                            },
                            onAddAddress: () async {
                              final result = await Navigator.of(context)
                                  .push<AddressModel>(
                                    MaterialPageRoute(
                                      builder: (_) => const AddressFormScreen(),
                                    ),
                                  );
                              if (!context.mounted || result == null) return;
                              try {
                                await context
                                    .read<AddressProvider>()
                                    .addAddress(result);
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unable to save address.'),
                                  ),
                                );
                              }
                            },
                          ),
                  ),
                  const SizedBox(height: defaultPadding),
                  _SectionCard(
                    title: 'Coupon',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _couponController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Enter coupon code',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: cartProvider.isApplyingCoupon
                                  ? null
                                  : () async {
                                      final success = await context
                                          .read<CartProvider>()
                                          .applyCoupon(_couponController.text);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context
                                                    .read<CartProvider>()
                                                    .couponMessage ??
                                                (success
                                                    ? 'Coupon applied.'
                                                    : 'Could not apply coupon.'),
                                          ),
                                        ),
                                      );
                                    },
                              child: Text(
                                cartProvider.isApplyingCoupon ? '...' : 'Apply',
                              ),
                            ),
                          ],
                        ),
                        if (cartProvider.appliedCoupon != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Applied: ${cartProvider.appliedCoupon!.code}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context
                                      .read<CartProvider>()
                                      .clearAppliedCoupon();
                                  _couponController.clear();
                                },
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        ],
                        if ((cartProvider.couponMessage ?? '')
                            .trim()
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              cartProvider.couponMessage!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: cartProvider.appliedCoupon != null
                                        ? successColor
                                        : Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  _SectionCard(
                    title: 'Payment method',
                    child: Column(
                      children: [
                        if (onlinePaymentAvailable) ...[
                          _PaymentMethodTile(
                            title: 'Razorpay',
                            subtitle:
                                'UPI, Google Pay, PhonePe, cards, and wallets',
                            isSelected:
                                _selectedPaymentMethod ==
                                _CheckoutPaymentMethod.razorpay,
                            onTap: () {
                              setState(() {
                                _selectedPaymentMethod =
                                    _CheckoutPaymentMethod.razorpay;
                              });
                            },
                            leadingIcon: Icons.account_balance_wallet_outlined,
                          ),
                          const SizedBox(height: defaultPadding / 2),
                        ],
                        _PaymentMethodTile(
                          title: 'Cash on Delivery',
                          subtitle:
                              'Pay when the order arrives at your address',
                          isSelected:
                              _selectedPaymentMethod ==
                              _CheckoutPaymentMethod.cod,
                          onTap: () {
                            setState(() {
                              _selectedPaymentMethod =
                                  _CheckoutPaymentMethod.cod;
                            });
                          },
                          leadingIcon: Icons.local_shipping_outlined,
                        ),
                        if (!onlinePaymentAvailable) ...[
                          const SizedBox(height: defaultPadding / 2),
                          Text(
                            isOnlinePaymentEnabled
                                ? 'Online payment will be available soon. You can still place your order with cash on delivery.'
                                : 'Online payment is currently turned off. You can still place your order with cash on delivery.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (_isRefreshingPaymentConfig) ...[
                          const SizedBox(height: defaultPadding / 2),
                          const Text('Refreshing payment settings...'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  _SectionCard(
                    title: 'Payment summary',
                    child: Column(
                      children: [
                        _PriceRow(
                          label: 'Subtotal',
                          value: _formatMoney(pricing.subtotal),
                        ),
                        if (pricing.productDiscount > 0) ...[
                          const SizedBox(height: defaultPadding / 4),
                          _PriceRow(
                            label: 'Product savings',
                            value: '-${_formatMoney(pricing.productDiscount)}',
                            valueStyle: const TextStyle(color: successColor),
                          ),
                        ],
                        const SizedBox(height: defaultPadding / 4),
                        _PriceRow(
                          label: 'Delivery charges',
                          value: pricing.deliveryCharge == 0
                              ? 'Free'
                              : _formatMoney(pricing.deliveryCharge),
                        ),
                        if (pricing.couponDiscount > 0) ...[
                          const SizedBox(height: defaultPadding / 4),
                          _PriceRow(
                            label: 'Coupon discount',
                            value: '-${_formatMoney(pricing.couponDiscount)}',
                            valueStyle: const TextStyle(color: successColor),
                          ),
                        ],
                        const Divider(height: defaultPadding * 1.5),
                        _PriceRow(
                          label: 'Total amount',
                          value: _formatMoney(pricing.total),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding * 1.5),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : () => _placeOrder(user),
                    child: Text(
                      _selectedPaymentMethod == _CheckoutPaymentMethod.cod
                          ? 'Place Order'
                          : 'Pay Now',
                    ),
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  Text(
                    _selectedPaymentMethod == _CheckoutPaymentMethod.cod
                        ? 'Pay in cash when your order arrives.'
                        : 'A secure payment page will open to complete your purchase.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.18),
                child: const AppLoadingIndicator(
                  message: 'Processing your order...',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _placeOrder(AppUserModel? user) async {
    final authProvider = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final addressProvider = context.read<AddressProvider>();
    final selectedAddress = addressProvider.selectedAddress;
    final items = cartProvider.items;
    final isRazorpayFlow =
        _selectedPaymentMethod == _CheckoutPaymentMethod.razorpay;

    if (!authProvider.isAuthenticated || user == null) {
      _showSnackBar('Please sign in to continue checkout.');
      return;
    }

    if (items.isEmpty) {
      _showSnackBar('Your cart is empty.');
      return;
    }

    if (selectedAddress == null) {
      _showSnackBar('Select a delivery address first.');
      return;
    }

    if (!_hasValidEmail(user.email)) {
      _showSnackBar(
        'Add a valid email in your profile before placing the order. The backend needs it to confirm the order and send your invoice.',
      );
      await Navigator.pushNamed(context, userInfoScreenRoute);
      return;
    }

    if (isRazorpayFlow && !isRazorpayConfigured) {
      await _refreshPaymentConfig();
    }

    if (isRazorpayFlow && !isRazorpayConfigured) {
      _showSnackBar(
        'Razorpay is not configured yet. Ask the admin to update the payment settings, or choose Cash on Delivery.',
      );
      return;
    }

    final orderId = _generateOrderId();
    final cartPricing = cartProvider.pricing;
    final pricing = OrderPricingModel(
      subtotal: cartPricing.subtotal,
      deliveryCharge: cartPricing.deliveryCharge,
      discount: cartPricing.totalDiscount,
      totalAmount: cartPricing.total,
      productDiscount: cartPricing.productDiscount,
      couponDiscount: cartPricing.couponDiscount,
      couponCode: cartProvider.appliedCoupon?.code,
    );
    final deliveryAddress = OrderDeliveryAddressModel.fromAddress(
      selectedAddress,
    );
    final paymentMethod = isRazorpayFlow
        ? PaymentMethod.razorpay
        : PaymentMethod.cod;
    final pendingPayment = OrderPaymentModel(
      paymentMethod: paymentMethod,
      paymentStatus: PaymentStatus.pending,
    );
    final draftOrder = _buildOrder(
      orderId: orderId,
      userId: user.uid,
      userName: user.name,
      userEmail: user.email,
      userPhone: user.phoneNumber ?? selectedAddress.phoneNumber,
      deliveryAddress: deliveryAddress,
      items: items,
      pricing: pricing,
      payment: pendingPayment,
    );

    setState(() {
      _isProcessing = true;
    });

    try {
      if (paymentMethod == PaymentMethod.cod) {
        final confirmed = await _confirmCashOnDelivery(
          totalAmount: pricing.totalAmount,
          itemCount: items.fold<int>(0, (total, item) => total + item.quantity),
          addressLabel: deliveryAddress.shortAddress,
        );
        if (!mounted || !confirmed) {
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        await _placeCashOnDeliveryOrder(draftOrder: draftOrder);
        return;
      }

      final razorpayOrder = await _checkoutApiService.createRazorpayOrder(
        amountInPaise: (pricing.totalAmount * 100).round(),
        receiptId: orderId,
        customerName: user.name,
        customerEmail: user.email,
        userId: user.uid,
        items: items,
        address: selectedAddress,
      );

      final razorpayDraft = draftOrder.copyWith(
        payment: OrderPaymentModel(
          paymentMethod: PaymentMethod.razorpay,
          paymentStatus: PaymentStatus.pending,
          razorpayOrderId: razorpayOrder.orderId,
        ),
      );

      _activeRazorpayOrderId = razorpayOrder.orderId;
      _activeRazorpayDraftOrder = razorpayDraft;
      _razorpaySessionResolved = false;

      await _savePendingRazorpayOrder(razorpayDraft);

      _razorpayService.openCheckout(
        orderId: razorpayOrder.orderId,
        amountInPaise: razorpayOrder.amountInPaise,
        keyId: razorpayOrder.keyId,
        merchantName: checkoutMerchantName,
        description: checkoutDescription,
        userName: user.name,
        userEmail: user.email,
        userPhone: user.phoneNumber ?? selectedAddress.phoneNumber,
        onSuccess: (response) {
          unawaited(
            _handleRazorpaySuccess(
              response,
              draftOrder: razorpayDraft,
              selectedAddress: selectedAddress,
            ),
          );
        },
        onFailure: (response) {
          unawaited(_handleRazorpayFailure(response));
        },
        onExternalWallet: (response) {
          if (!mounted) return;
          final walletName = response is Map
              ? (response['walletName'] ?? 'Unknown')
              : 'Unknown';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('External wallet selected: $walletName')),
          );
        },
      );
    } catch (error) {
      _resetRazorpaySession();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showSnackBar(_describeCheckoutError(error));
    }
  }

  Future<void> _handleRazorpaySuccess(
    PaymentSuccessResponse response, {
    required OrderModel draftOrder,
    required AddressModel selectedAddress,
  }) async {
    final verifiedPaymentId = response.paymentId;
    final verifiedOrderId = response.orderId;
    final verifiedSignature = response.signature;

    if (!_tryResolveRazorpaySession(orderId: verifiedOrderId)) {
      debugPrint(
        '[checkout] Ignoring stale Razorpay success for orderId=$verifiedOrderId active=$_activeRazorpayOrderId',
      );
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
        });
      }

      if (verifiedPaymentId == null ||
          verifiedOrderId == null ||
          verifiedSignature == null) {
        throw const CheckoutApiException(
          message:
              'Razorpay did not return the payment details needed for verification.',
        );
      }

      final verificationResult = await _checkoutApiService
          .verifyRazorpayPayment(
            razorpayOrderId: verifiedOrderId,
            razorpayPaymentId: verifiedPaymentId,
            razorpaySignature: verifiedSignature,
            receiptId: draftOrder.orderId,
            userId: draftOrder.userId,
            customerEmail: draftOrder.userEmail,
            customerName: draftOrder.userName,
            amountInPaise: (draftOrder.totalPrice * 100).round(),
            items: _buildCartItemsFromOrder(draftOrder.items),
            address: selectedAddress,
          );

      final confirmedOrderId =
          verificationResult.backendOrderId?.trim().isNotEmpty == true
          ? verificationResult.backendOrderId!.trim()
          : draftOrder.orderId;

      final paidOrder = draftOrder.copyWith(
        orderId: confirmedOrderId,
        payment: OrderPaymentModel(
          paymentMethod: PaymentMethod.razorpay,
          paymentStatus: PaymentStatus.paid,
          razorpayPaymentId: verifiedPaymentId,
          razorpayOrderId: verifiedOrderId,
          razorpaySignature: verifiedSignature,
        ),
        updatedAt: DateTime.now(),
      );

      await _finalizeSuccessfulOrder(
        order: paidOrder,
        successMessage:
            '${verificationResult.message} Order ID: ${paidOrder.orderId}. Confirmation email will be sent by the backend to ${draftOrder.userEmail}.',
      );
    } catch (error) {
      _razorpaySessionResolved = false;
      final errorDetails = _describeCheckoutError(error);
      debugPrint('[checkout] Razorpay success follow-up failed: $errorDetails');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment verification failed on the backend, so the order was not confirmed. Details: $errorDetails',
          ),
        ),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _refreshPaymentConfig() async {
    if (_isRefreshingPaymentConfig) {
      return;
    }

    _isRefreshingPaymentConfig = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final repository = context.read<StorefrontRepository>();
      final settings = await repository.getPaymentSettings();
      setRuntimePaymentSettings(settings);
    } catch (_) {
      // Keep the current fallback config if the runtime fetch fails.
    } finally {
      _isRefreshingPaymentConfig = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleRazorpayFailure(PaymentFailureResponse response) async {
    if (!_tryResolveRazorpaySession()) {
      debugPrint(
        '[checkout] Ignoring duplicate Razorpay failure code=${response.code} message=${response.message}',
      );
      return;
    }
    _razorpayService.dispose();
    await _markActiveRazorpayOrderFailed();
    debugPrint(
      '[checkout] Razorpay payment failure code=${response.code} message=${response.message}',
    );
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
    _showSnackBar(
      'Payment failed. Code: ${response.code}. Message: ${response.message ?? 'No message from Razorpay.'}',
    );
  }

  Future<void> _placeCashOnDeliveryOrder({
    required OrderModel draftOrder,
  }) async {
    final confirmedOrder = draftOrder.copyWith(
      payment: const OrderPaymentModel(
        paymentMethod: PaymentMethod.cod,
        paymentStatus: PaymentStatus.pending,
      ),
      orderStatus: OrderStatus.confirmed,
      updatedAt: DateTime.now(),
    );

    await _finalizeSuccessfulOrder(
      order: confirmedOrder,
      successMessage:
          'Cash on Delivery order placed successfully. Order ID: ${confirmedOrder.orderId}.',
    );
  }

  Future<void> _finalizeSuccessfulOrder({
    required OrderModel order,
    required String successMessage,
  }) async {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    }

    await _saveOrder(order);
  }

  Future<void> _savePendingRazorpayOrder(OrderModel order) async {
    final orderRepository = context.read<OrderRepository>();
    final orderProvider = context.read<OrderProvider>();

    await orderRepository.saveOrder(order);
    orderProvider.addOrder(order);
  }

  Future<void> _markActiveRazorpayOrderFailed() async {
    final draftOrder = _activeRazorpayDraftOrder;
    if (draftOrder == null) {
      return;
    }

    final failedOrder = draftOrder.copyWith(
      payment: OrderPaymentModel(
        paymentMethod: PaymentMethod.razorpay,
        paymentStatus: PaymentStatus.failed,
        razorpayOrderId: draftOrder.payment.razorpayOrderId,
      ),
      orderStatus: OrderStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    final orderRepository = context.read<OrderRepository>();
    final orderProvider = context.read<OrderProvider>();

    try {
      await orderRepository.saveOrder(failedOrder);
      orderProvider.addOrder(failedOrder);
    } catch (error) {
      debugPrint('[checkout] Failed to mark Razorpay order as failed: $error');
    }
  }

  Future<void> _saveOrder(OrderModel order) async {
    final orderRepository = context.read<OrderRepository>();
    final orderProvider = context.read<OrderProvider>();
    final cartProvider = context.read<CartProvider>();
    final productProvider = context.read<ProductProvider>();

    try {
      await orderRepository.saveOrder(order);
      orderProvider.addOrder(order);
    } catch (error) {
      debugPrint('[checkout] Local order sync failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order confirmed, but local order sync failed. The backend has already created the order.',
            ),
          ),
        );
      }
    }

    final invoiceResult = await orderProvider.saveInvoice(order);
    cartProvider.markCouponUsed();
    await productProvider.loadInitialData();
    await cartProvider.clear();
    _razorpayService.dispose();
    _resetRazorpaySession();

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });

    final invoiceMessage = invoiceResult == null
        ? null
        : invoiceResult.location == null
        ? 'Invoice saved as ${invoiceResult.fileName}.'
        : 'Invoice saved to ${invoiceResult.location}.';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            OrderSuccessScreen(order: order, invoiceMessage: invoiceMessage),
      ),
    );
  }

  bool _tryResolveRazorpaySession({String? orderId}) {
    if (_razorpaySessionResolved) {
      return false;
    }
    if (orderId != null &&
        _activeRazorpayOrderId != null &&
        orderId.trim().isNotEmpty &&
        orderId.trim() != _activeRazorpayOrderId) {
      return false;
    }
    _razorpaySessionResolved = true;
    return true;
  }

  void _resetRazorpaySession() {
    _activeRazorpayOrderId = null;
    _activeRazorpayDraftOrder = null;
    _razorpaySessionResolved = false;
  }

  Future<bool> _confirmCashOnDelivery({
    required double totalAmount,
    required int itemCount,
    required String addressLabel,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(defaultBorderRadious * 2),
          topRight: Radius.circular(defaultBorderRadious * 2),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.52,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  defaultPadding,
                  defaultPadding,
                  defaultPadding,
                  defaultPadding +
                      MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContext).dividerColor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    Text(
                      'Confirm cash on delivery',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please review the order details before placing it.',
                      style: Theme.of(sheetContext).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: defaultPadding),
                    _SectionCard(
                      title: 'Order summary',
                      child: Column(
                        children: [
                          _PriceRow(label: 'Items', value: '$itemCount'),
                          const SizedBox(height: defaultPadding / 3),
                          _PriceRow(
                            label: 'Payment',
                            value: 'Cash on Delivery',
                          ),
                          const SizedBox(height: defaultPadding / 3),
                          _PriceRow(
                            label: 'Deliver to',
                            value: addressLabel,
                            allowWrap: true,
                          ),
                          const SizedBox(height: defaultPadding / 3),
                          _PriceRow(
                            label: 'Total',
                            value: _formatMoney(totalAmount),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Review again'),
                    ),
                    const SizedBox(height: defaultPadding / 2),
                    ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Confirm order'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return confirmed == true;
  }

  OrderModel _buildOrder({
    required String orderId,
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required OrderDeliveryAddressModel deliveryAddress,
    required List<CartItemModel> items,
    required OrderPricingModel pricing,
    required OrderPaymentModel payment,
  }) {
    final now = DateTime.now();
    return OrderModel(
      orderId: orderId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      deliveryAddress: deliveryAddress,
      items: items.map(OrderItemModel.fromCartItem).toList(),
      pricing: pricing,
      payment: payment,
      orderStatus: OrderStatus.placed,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _generateOrderId() {
    final timeStamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = 1000 + _random.nextInt(9000);
    return 'ORD-$timeStamp-$suffix';
  }

  String _formatMoney(double amount) => 'Rs ${amount.toStringAsFixed(0)}';

  List<CartItemModel> _buildCartItemsFromOrder(List<OrderItemModel> items) {
    return items
        .map(
          (item) => CartItemModel(
            product: ProductModel(
              id: item.productId,
              name: item.productName,
              price: item.productPrice,
              imageUrl: item.imageUrl,
              brandName: '',
              salePrice: item.productPrice,
              stockQuantity: item.quantity,
            ),
            selectedOptionId: item.selectedOptionId,
            selectedOptionLabel: item.selectedOptionLabel,
            unitPrice: item.productPrice,
            originalUnitPrice: item.originalUnitPrice,
            quantity: item.quantity,
          ),
        )
        .toList();
  }

  bool _hasValidEmail(String email) {
    final trimmed = email.trim();
    return trimmed.isNotEmpty && trimmed.contains('@') && trimmed.contains('.');
  }

  String _describeCheckoutError(Object error) {
    if (error is CheckoutApiException) {
      return error.toDisplayMessage();
    }
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: const BorderRadius.all(
          Radius.circular(defaultBorderRadious),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: defaultPadding / 2),
          child,
        ],
      ),
    );
  }
}

class _CheckoutItemTile extends StatelessWidget {
  const _CheckoutItemTile({required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(defaultBorderRadious),
          ),
          child: Image.network(
            item.product.imageUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: defaultPadding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(item.product.brandName),
              if (item.selectedOptionLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Pack: ${item.selectedOptionLabel}'),
              ],
              const SizedBox(height: 4),
              Text('Qty ${item.quantity}'),
            ],
          ),
        ),
        Text(
          'Rs ${item.totalPrice.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.selectedAddress,
    required this.addresses,
    required this.onSelect,
    required this.onAddAddress,
  });

  final AddressModel? selectedAddress;
  final List<AddressModel> addresses;
  final ValueChanged<AddressModel> onSelect;
  final VoidCallback onAddAddress;

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No saved addresses yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: defaultPadding / 2),
          ElevatedButton(
            onPressed: onAddAddress,
            child: const Text('Add address'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedAddress == null
              ? 'Select a delivery address'
              : '${selectedAddress!.fullName} | ${selectedAddress!.phoneNumber}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: defaultPadding / 2),
        Text(
          selectedAddress?.fullAddress ?? 'Tap an address below to continue.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: defaultPadding),
        for (final address in addresses) ...[
          InkWell(
            onTap: () => onSelect(address),
            borderRadius: const BorderRadius.all(
              Radius.circular(defaultBorderRadious),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: defaultPadding / 2),
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                border: Border.all(
                  color: address.id == selectedAddress?.id
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
                borderRadius: const BorderRadius.all(
                  Radius.circular(defaultBorderRadious),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        address.id == selectedAddress?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: address.id == selectedAddress?.id
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (address.isDefault) const Text('Default'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${address.fullName} | ${address.phoneNumber}'),
                  const SizedBox(height: 4),
                  Text(address.fullAddress),
                ],
              ),
            ),
          ),
        ],
        OutlinedButton(
          onPressed: onAddAddress,
          child: const Text('Add new address'),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(
        Radius.circular(defaultBorderRadious),
      ),
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          borderRadius: const BorderRadius.all(
            Radius.circular(defaultBorderRadious),
          ),
        ),
        child: Row(
          children: [
            Icon(leadingIcon),
            const SizedBox(width: defaultPadding / 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueStyle,
    this.allowWrap = false,
  });

  final String label;
  final String value;
  final bool isBold;
  final TextStyle? valueStyle;
  final bool allowWrap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = isBold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyLarge;
    final resolvedValueStyle = valueStyle ?? baseStyle;

    return Row(
      crossAxisAlignment: allowWrap
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: allowWrap ? 2 : 1,
          child: Text(label, style: baseStyle),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: allowWrap ? 3 : 1,
          child: Text(
            value,
            style: resolvedValueStyle,
            textAlign: TextAlign.right,
            softWrap: allowWrap,
            overflow: allowWrap ? TextOverflow.visible : TextOverflow.ellipsis,
            maxLines: allowWrap ? null : 1,
          ),
        ),
      ],
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: defaultPadding),
            Text(
              'Sign in to checkout',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: defaultPadding / 2),
            const Text(
              'We need your account details to create and save the order.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: defaultPadding),
            ElevatedButton(
              onPressed: onSignIn,
              child: const Text('Go to login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCheckoutState extends StatelessWidget {
  const _EmptyCheckoutState({required this.onContinueShopping});

  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: defaultPadding),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: defaultPadding / 2),
            const Text(
              'Add items to your cart before starting checkout.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: defaultPadding),
            ElevatedButton(
              onPressed: onContinueShopping,
              child: const Text('Continue shopping'),
            ),
          ],
        ),
      ),
    );
  }
}
