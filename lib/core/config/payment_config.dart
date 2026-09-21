import 'package:shop/models/payment_settings_model.dart';

const String fallbackRazorpayKeyId = 'rzp_live_SyPdRHQpIyZi2a';
const String fallbackRazorpayBackendBaseUrl =
    'https://asia-south1-pet-shop-app-ee6f2.cloudfunctions.net';

final PaymentSettingsModel _defaultPaymentSettings = PaymentSettingsModel(
  keyId: const String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: fallbackRazorpayKeyId,
  ),
  backendBaseUrl: _configuredBackendBaseUrl,
  currency: const String.fromEnvironment(
    'RAZORPAY_CURRENCY',
    defaultValue: 'INR',
  ),
  merchantName: const String.fromEnvironment(
    'CHECKOUT_MERCHANT_NAME',
    defaultValue: 'Store Checkout',
  ),
  checkoutDescription: const String.fromEnvironment(
    'CHECKOUT_DESCRIPTION',
    defaultValue: 'Order payment',
  ),
);

PaymentSettingsModel _runtimePaymentSettings = _defaultPaymentSettings;

const String _configuredBackendBaseUrl = String.fromEnvironment(
  'RAZORPAY_BACKEND_BASE_URL',
  defaultValue: fallbackRazorpayBackendBaseUrl,
);

PaymentSettingsModel get currentPaymentSettings => _runtimePaymentSettings;

void setRuntimePaymentSettings(PaymentSettingsModel? settings) {
  _runtimePaymentSettings = (settings ?? const PaymentSettingsModel())
      .mergeWith(_defaultPaymentSettings);
}

String get razorpayKeyId => currentPaymentSettings.keyId.trim();

String get razorpayBackendBaseUrl => currentPaymentSettings.backendBaseUrl.trim();

String get razorpayCurrency => currentPaymentSettings.currency.trim().toUpperCase();

String get checkoutMerchantName => currentPaymentSettings.merchantName.trim();

String get checkoutDescription =>
    currentPaymentSettings.checkoutDescription.trim();

bool get isRazorpayConfigured => razorpayBackendBaseUrl.trim().isNotEmpty;
bool get isRazorpayPublicKeyConfigured => razorpayKeyId.trim().isNotEmpty;
bool get isOnlinePaymentEnabled =>
    currentPaymentSettings.isOnlinePaymentEnabled;
bool get isOnlinePaymentAvailable =>
    currentPaymentSettings.isOnlinePaymentAvailable;

String get razorpayOrderCreationUrl {
  if (razorpayBackendBaseUrl.contains('cloudfunctions.net')) {
    return _resolveBackendPath('/createRazorpayOrder');
  }
  return _resolveBackendPath('/create-order');
}

String get razorpayPaymentVerificationUrl {
  if (razorpayBackendBaseUrl.contains('cloudfunctions.net')) {
    return _resolveBackendPath('/verifyRazorpayPayment');
  }
  return _resolveBackendPath('/verify-payment');
}

String get codOrderCreationUrl => _resolveBackendPath('/orders');

String _resolveBackendPath(String path) {
  var baseUrl = razorpayBackendBaseUrl.trim();
  if (baseUrl.isEmpty) {
    return '';
  }

  // Iteratively strip known endpoint suffixes (including /api) so that URLs like
  // "...cloudfunctions.net/api/createRazorpayOrder" or "...cloudfunctions.net/api"
  // resolve cleanly to the root base URL "...cloudfunctions.net".
  bool stripped;
  do {
    stripped = false;
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    for (final suffix in [
      '/createRazorpayOrder',
      '/create-order',
      '/createOrder',
      '/verifyRazorpayPayment',
      '/verify-payment',
      '/verifyPayment',
      '/orders',
      '/api',
    ]) {
      if (baseUrl.toLowerCase().endsWith(suffix.toLowerCase())) {
        baseUrl = baseUrl.substring(0, baseUrl.length - suffix.length);
        stripped = true;
        break;
      }
    }
  } while (stripped);

  return '$baseUrl$path';
}
