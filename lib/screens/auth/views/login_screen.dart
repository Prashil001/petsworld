import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/order_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';

import 'components/auth_feedback.dart';
import 'components/auth_shell.dart';
import 'components/login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _acceptedPrivacyPolicy = false;

  Future<void> _resendVerificationEmail(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final auth = context.read<AuthProvider>();

    if (email.isEmpty) {
      await showAuthErrorDialog(
        context,
        message: 'Enter your email address first.',
      );
      return;
    }

    if (password.isEmpty) {
      await showAuthErrorDialog(
        context,
        message: 'Enter your password to resend the verification email.',
      );
      return;
    }

    final success = await auth.sendEmailVerification(
      email: email,
      password: password,
    );

    if (!context.mounted) return;

    if (!success) {
      await showAuthErrorDialog(
        context,
        message:
            auth.errorMessage ??
            'Unable to resend the verification email right now.',
      );
      auth.clearError();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Verification email sent to $email. Please check inbox, spam, or promotions.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return AuthShell(
      eyebrow: 'WELCOME BACK',
      title: 'Sign in to your account',
      subtitle: 'Access your cart, saved products, and orders in one place.',
      footer: Center(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("Don't have an account? ", style: theme.textTheme.bodyMedium),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, signUpScreenRoute);
              },
              child: const Text('Create one'),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoStrip(
            icon: Icons.verified_user_outlined,
            text:
                'Email/password accounts require verification before first login.',
          ),
          const SizedBox(height: 20),
          LogInForm(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
          ),
          const SizedBox(height: 18),
          _buildPrimaryButton(context, authProvider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: theme.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(child: Divider(color: theme.dividerColor)),
            ],
          ),
          const SizedBox(height: 14),
          _AuthActionButton(
            label: 'Continue with phone OTP',
            icon: Icons.sms_outlined,
            onPressed: authProvider.isLoading
                ? null
                : () {
                    Navigator.pushNamed(
                      context,
                      phoneAuthScreenRoute,
                      arguments: const <String, dynamic>{'isSignUp': false},
                    );
                  },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: authProvider.isLoading
                  ? null
                  : () {
                      Navigator.pushNamed(context, passwordRecoveryScreenRoute);
                    },
              child: const Text('Forgot password?'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: authProvider.isLoading
                  ? null
                  : () => _resendVerificationEmail(context),
              child: const Text('Resend verification email'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedPrivacyPolicy,
                onChanged: authProvider.isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _acceptedPrivacyPolicy = value ?? false;
                        });
                      },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      text: 'By logging in, you agree to the',
                      style: theme.textTheme.bodyMedium,
                      children: [
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              privacyPolicyScreenRoute,
                            ),
                            child: Text(
                              ' Privacy Policy.',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFFF6C667)
                                    : const Color(0xFF18392F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, AuthProvider authProvider) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1E242B),
          borderRadius: BorderRadius.circular(22),
        ),
        child: ElevatedButton(
          onPressed: authProvider.isLoading ? null : () => _signIn(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Text(
            authProvider.isLoading ? 'Please wait...' : 'Log in',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPrivacyPolicy) {
      await showAuthErrorDialog(
        context,
        message: 'Please agree to the Privacy Policy to continue.',
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final productProvider = context.read<ProductProvider>();
    final orderProvider = context.read<OrderProvider>();
    final navigator = Navigator.of(context);
    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!context.mounted) return;
    if (!success) {
      final message =
          auth.errorMessage ?? 'Unable to log in with email and password.';
      await showAuthErrorDialog(context, message: message);
      auth.clearError();
      return;
    }

    final userId = auth.currentUser?.uid;
    await cartProvider.syncForUser(userId);
    await productProvider.syncUserData(userId);
    await orderProvider.syncForUser(userId);

    if (!context.mounted) return;
    navigator.pushNamedAndRemoveUntil(entryPointScreenRoute, (route) => false);
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

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

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : const Color(0xFF20262D);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          side: BorderSide(
            color: isDark ? const Color(0xFF313A47) : const Color(0xFFD9DAD6),
          ),
          backgroundColor: isDark ? const Color(0xFF181E27) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        icon: Icon(icon, color: foregroundColor, size: 20),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: null,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}
