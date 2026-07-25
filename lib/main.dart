import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/core/app/app_scope.dart';
import 'package:shop/core/config/payment_config.dart';
import 'package:shop/core/services/firebase_bootstrap.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/entry_point.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/order_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/providers/theme_provider.dart';
import 'package:shop/repositories/storefront_repository.dart';
import 'package:shop/route/router.dart' as router;
import 'package:shop/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const AppScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PetsWorld',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeProvider.themeMode,
      onGenerateRoute: router.generateRoute,
      home: const AppLaunchGate(),
    );
  }
}

class AppLaunchGate extends StatelessWidget {
  const AppLaunchGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SessionSyncGate();
  }
}

class _SessionSyncGate extends StatefulWidget {
  const _SessionSyncGate();

  @override
  State<_SessionSyncGate> createState() => _SessionSyncGateState();
}

class _SessionSyncGateState extends State<_SessionSyncGate> {
  String? _lastSyncedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (_lastSyncedUserId == userId) {
      return;
    }

    _lastSyncedUserId = userId;

    Future.microtask(() async {
      if (!mounted) {
        return;
      }

      await context.read<CartProvider>().syncForUser(userId);
      if (!mounted) {
        return;
      }

      await context.read<ProductProvider>().syncUserData(userId);
      if (!mounted) {
        return;
      }

      await context.read<OrderProvider>().syncForUser(userId);

      if (!mounted) {
        return;
      }

      try {
        final settings = await context
            .read<StorefrontRepository>()
            .getPaymentSettings();
        setRuntimePaymentSettings(settings);
      } catch (_) {
        // Use bundled fallbacks when runtime settings are unavailable.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Getting things ready...'),
      );
    }

    return const EntryPoint();
  }
}
