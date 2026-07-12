import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/screens/auth/views/components/auth_feedback.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (!_didInit && user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phoneNumber ?? '';
      _didInit = true;
    }

    final initials = _initialsFor(user?.name);
    // Phone-OTP accounts have no Firebase Auth email/password credential,
    // so their email is just a contact field, safe to edit here. Email
    // (and Apple) accounts keep it locked since it's tied to their login.
    final isPhoneAccount = (user?.phoneNumber ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile details')),
      body: user == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Text('Please log in to view your profile.'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(defaultPadding),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFFE9ECFF),
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Color(0xFF4B57D9),
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.trim().isEmpty
                                      ? 'Pet Parent'
                                      : _nameController.text.trim(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _emailController.text.trim().isNotEmpty
                                      ? _emailController.text.trim()
                                      : (_phoneController.text.trim().isNotEmpty
                                            ? _phoneController.text.trim()
                                            : 'No email linked'),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.86),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    Container(
                      padding: const EdgeInsets.all(defaultPadding),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: defaultPadding),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              hintText: 'Enter your name',
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: defaultPadding),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: !isPhoneAccount,
                            enabled: isPhoneAccount,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: isPhoneAccount
                                  ? 'Add an email for order receipts and payments'
                                  : 'Email cannot be changed here',
                            ),
                            validator: (value) {
                              if (!isPhoneAccount) return null;
                              final trimmed = (value ?? '').trim();
                              if (trimmed.isEmpty) return null;
                              final isValid =
                                  trimmed.contains('@') &&
                                  trimmed.contains('.') &&
                                  !trimmed.startsWith('@') &&
                                  !trimmed.endsWith('@');
                              if (!isValid) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: defaultPadding),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            readOnly: true,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: 'Phone number cannot be changed here',
                            ),
                          ),
                          const SizedBox(height: defaultPadding * 1.2),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () async {
                                      final authNotifier = context
                                          .read<AuthProvider>();
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      final success = await authNotifier
                                          .updateProfile(
                                            name: _nameController.text,
                                            email: isPhoneAccount
                                                ? _emailController.text
                                                : null,
                                          );
                                      if (!context.mounted) return;
                                      if (!success) {
                                        final message =
                                            authNotifier.errorMessage ??
                                            'Unable to update profile.';
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
                                            'Profile updated successfully.',
                                          ),
                                        ),
                                      );
                                    },
                              child: Text(
                                authProvider.isLoading
                                    ? 'Saving...'
                                    : 'Save profile',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _initialsFor(String? name) {
    final value = (name ?? '').trim();
    if (value.isEmpty) return 'U';
    final parts = value
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
