import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/screens/auth/views/components/auth_feedback.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    if (_emailController.text.trim().isEmpty) {
      _emailController.text = authProvider.currentUser?.email ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your account email and we will send a password reset link.',
              ),
              const SizedBox(height: defaultPadding),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) {
                    return 'Email is required';
                  }
                  if (!text.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: defaultPadding * 1.5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          final authNotifier = context.read<AuthProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          if (!_formKey.currentState!.validate()) return;
                          final email = _emailController.text.trim();

                          final success = await authNotifier
                              .sendPasswordResetEmail(email);
                          if (!context.mounted) return;
                          if (!success) {
                            final message =
                                authNotifier.errorMessage ??
                                'Unable to send reset email right now.';
                            await showAuthErrorDialog(
                              context,
                              message: message,
                            );
                            authNotifier.clearError();
                            return;
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Reset email requested. Check inbox, spam, and Promotions tab.',
                              ),
                            ),
                          );
                          navigator.pop();
                        },
                  child: Text(
                    authProvider.isLoading ? 'Sending...' : 'Send reset email',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
