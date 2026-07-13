import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/constants.dart';
import 'package:shop/models/delivery_settings_model.dart';
import 'package:shop/models/payment_settings_model.dart';
import 'package:shop/providers/admin_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/product_provider.dart';

class AdminStoreSettingsScreen extends StatefulWidget {
  const AdminStoreSettingsScreen({super.key});

  @override
  State<AdminStoreSettingsScreen> createState() =>
      _AdminStoreSettingsScreenState();
}

class _AdminStoreSettingsScreenState extends State<AdminStoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _thresholdController;
  late final TextEditingController _feeController;
  late final TextEditingController _whatsAppController;
  late final TextEditingController _razorpayKeyIdController;
  late final TextEditingController _razorpayBackendUrlController;
  late final TextEditingController _razorpayCurrencyController;
  late final TextEditingController _merchantNameController;
  late final TextEditingController _checkoutDescriptionController;
  bool _isOnlinePaymentEnabled = true;

  @override
  void initState() {
    super.initState();
    final adminProvider = context.read<AdminProvider>();
    final settings = adminProvider.deliverySettings;
    final paymentSettings = adminProvider.paymentSettings;
    _thresholdController = TextEditingController(
      text: settings.freeDeliveryThreshold.toStringAsFixed(0),
    );
    _feeController = TextEditingController(
      text: settings.deliveryFee.toStringAsFixed(0),
    );
    _whatsAppController = TextEditingController(
      text: settings.supportWhatsAppNumber,
    );
    _razorpayKeyIdController = TextEditingController(
      text: paymentSettings.keyId,
    );
    _razorpayBackendUrlController = TextEditingController(
      text: paymentSettings.backendBaseUrl,
    );
    _razorpayCurrencyController = TextEditingController(
      text: paymentSettings.currency,
    );
    _merchantNameController = TextEditingController(
      text: paymentSettings.merchantName,
    );
    _checkoutDescriptionController = TextEditingController(
      text: paymentSettings.checkoutDescription,
    );
    _isOnlinePaymentEnabled = paymentSettings.isOnlinePaymentEnabled;
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _feeController.dispose();
    _whatsAppController.dispose();
    _razorpayKeyIdController.dispose();
    _razorpayBackendUrlController.dispose();
    _razorpayCurrencyController.dispose();
    _merchantNameController.dispose();
    _checkoutDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Store settings')),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage free delivery and customer support contact details from one place.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'WhatsApp support',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This number is used by the Customer support > Chat on WhatsApp button in the app.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _whatsAppController,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (digits.isEmpty) {
                        return 'Enter a WhatsApp number';
                      }
                      if (digits.length < 10) {
                        return 'Enter a valid WhatsApp number with country code';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp support number',
                      hintText: 'Example: 919876543210',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Razorpay checkout',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'These values are safe to manage from the admin app. Keep the Razorpay secret only on your backend server.',
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isOnlinePaymentEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isOnlinePaymentEnabled = value;
                      });
                    },
                    title: const Text('Enable online payment'),
                    subtitle: const Text(
                      'Turn this off to hide Razorpay from checkout and allow only Cash on Delivery.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _razorpayKeyIdController,
                    decoration: const InputDecoration(
                      labelText: 'Razorpay key ID',
                      hintText: 'Example: rzp_live_xxxxxxxx',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _razorpayBackendUrlController,
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return 'Enter the backend base URL';
                      }
                      final uri = Uri.tryParse(trimmed);
                      if (uri == null ||
                          !(uri.hasScheme &&
                              (uri.isScheme('http') ||
                                  uri.isScheme('https')))) {
                        return 'Enter a valid backend URL';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Backend base URL',
                      hintText: 'Example: https://your-backend.example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _razorpayCurrencyController,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return 'Enter a currency code';
                      }
                      if (trimmed.length != 3) {
                        return 'Use a 3-letter currency code';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      hintText: 'INR',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _merchantNameController,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter a merchant name'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Checkout merchant name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _checkoutDescriptionController,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter a checkout description'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Checkout description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Changing the full Razorpay account still requires the backend service to use the matching secret for order creation and signature verification.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Free delivery rule',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final threshold = double.tryParse((value ?? '').trim());
                      if (threshold == null || threshold <= 0) {
                        return 'Enter a threshold greater than 0';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Free delivery threshold (Rs)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _feeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final fee = double.tryParse((value ?? '').trim());
                      if (fee == null || fee <= 0) {
                        return 'Enter a delivery fee greater than 0';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Delivery fee (Rs)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: adminProvider.isSaving ? null : _save,
                      child: Text(
                        adminProvider.isSaving ? 'Saving...' : 'Save settings',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final productProvider = context.read<ProductProvider>();
    final cartProvider = context.read<CartProvider>();

    final settings = DeliverySettingsModel(
      freeDeliveryThreshold:
          double.tryParse(_thresholdController.text.trim()) ?? 999,
      deliveryFee: double.tryParse(_feeController.text.trim()) ?? 49,
      supportWhatsAppNumber: _whatsAppController.text.trim(),
    );
    final paymentSettings = PaymentSettingsModel(
      isOnlinePaymentEnabled: _isOnlinePaymentEnabled,
      keyId: _razorpayKeyIdController.text.trim(),
      backendBaseUrl: _razorpayBackendUrlController.text.trim(),
      currency: _razorpayCurrencyController.text.trim().toUpperCase(),
      merchantName: _merchantNameController.text.trim(),
      checkoutDescription: _checkoutDescriptionController.text.trim(),
    );

    final adminProvider = context.read<AdminProvider>();
    final deliverySaved = await adminProvider.saveDeliverySettings(settings);
    if (!mounted) return;
    if (!deliverySaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminProvider.errorMessage ?? 'Could not save delivery settings.',
          ),
        ),
      );
      return;
    }
    final paymentSaved = await adminProvider.savePaymentSettings(
      paymentSettings,
    );
    if (!mounted) return;
    if (!paymentSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminProvider.errorMessage ?? 'Could not save payment settings.',
          ),
        ),
      );
      return;
    }
    await productProvider.loadInitialData();
    await cartProvider.loadPricingConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Store settings saved.')));
  }
}
