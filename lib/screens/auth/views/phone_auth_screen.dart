import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/order_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/auth/views/components/auth_feedback.dart';
import 'package:shop/screens/auth/views/components/auth_shell.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.isSignUp = false, this.prefilledName});

  final bool isSignUp;
  final String? prefilledName;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.prefilledName?.trim() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    try {
      context.read<AuthProvider>().clearPhoneAuthState();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _syncAndOpenApp() async {
    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final productProvider = context.read<ProductProvider>();
    final orderProvider = context.read<OrderProvider>();

    final userId = auth.currentUser?.uid;
    await cartProvider.syncForUser(userId);
    await productProvider.syncUserData(userId);
    await orderProvider.syncForUser(userId);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(entryPointScreenRoute, (route) => false);
  }

  String _normalizePhoneNumber(String input) {
    final value = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (value.startsWith('+')) return value;

    final onlyDigits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.length == 10) {
      return '+91$onlyDigits';
    }
    if (onlyDigits.length == 11 && onlyDigits.startsWith('0')) {
      return '+91${onlyDigits.substring(1)}';
    }
    if (onlyDigits.length == 12 && onlyDigits.startsWith('91')) {
      return '+$onlyDigits';
    }
    return onlyDigits.isNotEmpty ? '+$onlyDigits' : value;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return AuthShell(
      eyebrow: widget.isSignUp ? 'PHONE SIGN UP' : 'PHONE SIGN IN',
      title: widget.isSignUp ? 'Create account with OTP' : 'Continue with OTP',
      subtitle:
          'Use your mobile number to receive a one-time code and continue securely.',
      footer: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(
            widget.isSignUp
                ? 'Back to sign up options'
                : 'Back to login options',
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PhoneAuthInfoCard(
              icon: Icons.sms_outlined,
              text:
                  'We will send a one-time code to your mobile number so you can continue securely.',
            ),
            const SizedBox(height: defaultPadding),
            if (widget.isSignUp) ...[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Full name (optional)',
                ),
              ),
              const SizedBox(height: defaultPadding),
            ],
            Form(
              key: _phoneFormKey,
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Phone number is required';
                  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 10) {
                    return 'Enter a valid number (example: +919876543210)';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: 'Phone number (example: +919876543210)',
                ),
              ),
            ),
            const SizedBox(height: defaultPadding),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E242B),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ElevatedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          if (!_phoneFormKey.currentState!.validate()) return;
                          final normalizedPhone = _normalizePhoneNumber(
                            _phoneController.text,
                          );
                          _phoneController.text = normalizedPhone;

                          final success = await auth.requestPhoneOtp(
                            phoneNumber: normalizedPhone,
                          );
                          if (!context.mounted) return;
                          if (!success) {
                            final message =
                                auth.errorMessage ??
                                'Unable to send OTP right now.';
                            await showAuthErrorDialog(
                              context,
                              message: message,
                            );
                            auth.clearError();
                            return;
                          }

                          if (!auth.isPhoneOtpRequested) {
                            await _syncAndOpenApp();
                            return;
                          }

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('OTP sent successfully.'),
                            ),
                          );
                          await Navigator.of(context).pushNamed(
                            otpScreenRoute,
                            arguments: {
                              'phoneNumber': normalizedPhone,
                              'preferredName': _nameController.text.trim(),
                              'isSignUp': widget.isSignUp,
                            },
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    authProvider.isLoading ? 'Please wait...' : 'Send OTP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your number with +91 or just the 10-digit mobile number.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: defaultPadding),
            Text(
              'The OTP entry opens on the next page after the code is sent.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(
                  alpha: 0.72,
                ),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PhoneAuthInfoCard extends StatelessWidget {
  const _PhoneAuthInfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202733) : const Color(0xFFF6F6F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A333F) : const Color(0xFFE7E7E1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF5D646E),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
