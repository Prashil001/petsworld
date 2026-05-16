import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/core/app/app_scope.dart';
import 'package:shop/core/services/firebase_bootstrap.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/route/router.dart' as router;
import 'package:shop/screens/admin/views/admin_dashboard_screen.dart';
import 'package:shop/screens/admin/views/admin_login_screen.dart';
import 'package:shop/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const AppScope(child: AdminWebApp()));
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PetsWorld Admin',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      onGenerateRoute: router.generateRoute,
      home: const _AdminSessionGate(),
    );
  }
}

class _AdminSessionGate extends StatefulWidget {
  const _AdminSessionGate();

  @override
  State<_AdminSessionGate> createState() => _AdminSessionGateState();
}

class _AdminSessionGateState extends State<_AdminSessionGate> {
  String? _handledNonAdminUserId;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Opening admin workspace...'),
      );
    }

    if (auth.isAuthenticated && auth.isAdmin) {
      return const AdminDashboardScreen();
    }

    if (auth.isAuthenticated && !auth.isAdmin) {
      _signOutNonAdminSession(context, auth.currentUser?.uid);
      return const AdminLoginScreen(
        message: 'This account is not an admin account.',
      );
    }

    return AdminLoginScreen(message: _message);
  }

  void _signOutNonAdminSession(BuildContext context, String? userId) {
    if (_handledNonAdminUserId == userId) {
      return;
    }

    _handledNonAdminUserId = userId;
    final authProvider = context.read<AuthProvider>();
    Future.microtask(() async {
      await authProvider.signOut().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      if (!mounted) return;
      setState(() {
        _message = 'This account is not an admin account.';
      });
    });
  }
}
