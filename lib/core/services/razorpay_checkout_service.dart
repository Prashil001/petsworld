import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:shop/core/config/payment_config.dart';

class RazorpayCheckoutService {
  RazorpayCheckoutService() : _razorpay = Razorpay();

  final Razorpay _razorpay;

  void openCheckout({
    required String orderId,
    required int amountInPaise,
    String? keyId,
    required String merchantName,
    required String description,
    required String userName,
    required String userEmail,
    required String userPhone,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onFailure,
    void Function(dynamic response)? onExternalWallet,
  }) {
    final resolvedKeyId = (keyId?.trim().isNotEmpty == true)
        ? keyId!.trim()
        : razorpayKeyId.trim();

    if (resolvedKeyId.isEmpty) {
      throw StateError(
        'Razorpay key ID is unavailable. Make sure the backend returns keyId or set RAZORPAY_KEY_ID.',
      );
    }

    _razorpay.clear();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    if (onExternalWallet != null) {
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
    }

    final cleanPhone = userPhone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    final cleanEmail = userEmail.trim();
    final cleanName = userName.trim();

    final options = <String, dynamic>{
      'key': resolvedKeyId,
      'amount': amountInPaise,
      'currency': razorpayCurrency,
      'order_id': orderId,
      'name': merchantName,
      'description': description,
      'prefill': <String, dynamic>{
        if (cleanPhone.isNotEmpty) 'contact': cleanPhone,
        if (cleanEmail.isNotEmpty) 'email': cleanEmail,
        if (cleanName.isNotEmpty) 'name': cleanName,
      },
      'readonly': <String, dynamic>{
        if (cleanEmail.isNotEmpty) 'email': true,
        if (cleanPhone.isNotEmpty) 'contact': true,
        if (cleanName.isNotEmpty) 'name': true,
      },
      'retry': <String, dynamic>{'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'method': <String, dynamic>{
        'upi': true,
        'card': true,
        'netbanking': true,
        'wallet': true,
      },
      'theme': <String, dynamic>{'color': '#0C7D69'},
    };

    _razorpay.open(options);
  }

  void dispose() {
    _razorpay.clear();
  }
}
