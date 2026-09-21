import 'dart:async';
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

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({
    super.key,
    this.phoneNumber,
    this.preferredName,
    this.isSignUp = false,
  });

  final String? phoneNumber;
  final String? preferredName;
  final bool isSignUp;

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final GlobalKey<FormState> _otpFormKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  Timer? _resendTimer;
  int _secondsRemaining = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
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

  Future<void> _submitOtp() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;

    if (!_otpFormKey.currentState!.validate()) {
      return;
    }

    final success = await auth.verifyPhoneOtp(
      smsCode: _otpController.text.trim(),
      preferredName: widget.preferredName,
    );

    if (!mounted) return;

    if (!success) {
      final message = auth.errorMessage ?? 'Unable to verify OTP right now.';
      await showAuthErrorDialog(context, message: message);
      auth.clearError();
      return;
    }

    await _syncAndOpenApp();
  }

  Future<void> _resendOtp(String targetPhone) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.requestPhoneOtp(
      phoneNumber: targetPhone,
      isResend: true,
    );

    if (!mounted) return;

    if (!success) {
      final message = auth.errorMessage ?? 'Unable to resend OTP right now.';
      await showAuthErrorDialog(context, message: message);
      auth.clearError();
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('A new OTP has been sent to $targetPhone.'),
      ),
    );
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final resolvedPhone =
        widget.phoneNumber ?? authProvider.pendingPhoneNumber;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AuthShell(
      eyebrow: widget.isSignUp ? 'VERIFY PHONE SIGN UP' : 'PHONE VERIFICATION',
      title: 'Enter OTP code',
      subtitle: resolvedPhone == null
          ? 'Enter the 6-digit code sent to your mobile number.'
          : 'Enter the 6-digit code sent to $resolvedPhone.',
      footer: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Change phone number'),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhoneAuthInfoCard(
              icon: Icons.mark_chat_read_outlined,
              text: resolvedPhone != null
                  ? 'We sent a verification code to $resolvedPhone. Enter it below to continue.'
                  : 'OTP sent. Enter the 6-digit code to finish signing in.',
            ),
            const SizedBox(height: defaultPadding * 1.25),
            Form(
              key: _otpFormKey,
              child: TextFormField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 14.0,
                ),
                validator: (value) {
                  final code = value?.trim() ?? '';
                  if (code.isEmpty) return 'Please enter the OTP';
                  if (code.length != 6) return 'Enter the complete 6-digit OTP';
                  return null;
                },
                onChanged: (value) {
                  if (value.trim().length == 6) {
                    _submitOtp();
                  }
                },
                onFieldSubmitted: (_) => _submitOtp(),
                decoration: InputDecoration(
                  hintText: '••••••',
                  hintStyle: TextStyle(
                    letterSpacing: 14.0,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF101722)
                      : const Color(0xFFFFFCF7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF2B3445)
                          : const Color(0xFFD9D0C2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF2B3445)
                          : const Color(0xFFD9D0C2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFFF6C667)
                          : const Color(0xFF18392F),
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: errorColor),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: errorColor, width: 1.5),
                  ),
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
                  onPressed: authProvider.isLoading ? null : _submitOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    authProvider.isLoading
                        ? 'Verifying...'
                        : 'Verify & continue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: defaultPadding),
            Center(
              child: _canResend
                  ? TextButton.icon(
                      onPressed: authProvider.isLoading || resolvedPhone == null
                          ? null
                          : () => _resendOtp(resolvedPhone),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Resend OTP',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                  : Text(
                      'Resend OTP in ${_secondsRemaining}s',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.65,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'If the code does not arrive, wait for the timer to finish and tap Resend OTP, or verify that your phone number is correct.',
              textAlign: TextAlign.center,
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
