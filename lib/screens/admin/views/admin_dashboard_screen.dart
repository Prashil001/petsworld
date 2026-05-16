import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/core/config/cloudinary_config.dart';
import 'package:shop/core/config/payment_config.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/providers/admin_provider.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/admin/views/admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    if (!authProvider.isAdmin ||
        adminProvider.hasLoadedData ||
        adminProvider.isLoading) {
      return;
    }

    _requestedLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AdminProvider>().loadAdminData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final adminProvider = context.watch<AdminProvider>();

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin panel')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(defaultPadding),
            child: Text(
              'This area is only available for admin accounts.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (adminProvider.isLoading && !adminProvider.hasLoadedData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final products = adminProvider.products;
    final orders = adminProvider.orders;
    final categories = adminProvider.categories;
    final banners = adminProvider.homeBanners;

    final deliveredOrders = orders.where((order) => order.isDelivered).toList();
    final cancelledOrders = orders.where((order) => order.isCancelled).toList();
    final openOrders = orders.where((order) => !order.isCompleted).toList();
    final deliveredRevenue = deliveredOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalPrice,
    );
    final outstandingRevenue = openOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalPrice,
    );
    final averageDeliveredOrderValue = deliveredOrders.isEmpty
        ? 0.0
        : deliveredRevenue / deliveredOrders.length;
    final featuredProducts = products
        .where((product) => product.isFeatured)
        .length;
    final activeProducts = products.where((product) => product.isActive).length;
    final activeBanners = banners.where((banner) => banner.isActive).length;

    final categoryBreakdown = <String, int>{};
    for (final product in products) {
      final key = product.category.trim().isEmpty
          ? 'Unassigned'
          : product.category.trim();
      categoryBreakdown[key] = (categoryBreakdown[key] ?? 0) + 1;
    }
    final categoryEntries = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1180;
        final isTablet = constraints.maxWidth >= 760;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: isDesktop
              ? null
              : AppBar(
                  title: const Text('Admin Dashboard'),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                ),
          body: RefreshIndicator(
            onRefresh: () => context.read<AdminProvider>().loadAdminData(),
            child: isDesktop
                ? Row(
                    children: [
                      const _AdminSidebar(),
                      Expanded(
                        child: _DashboardContent(
                          isDesktop: true,
                          isTablet: true,
                          orders: orders,
                          categoriesCount: categories.length,
                          totalProducts: products.length,
                          featuredProducts: featuredProducts,
                          activeProducts: activeProducts,
                          activeBanners: activeBanners,
                          openOrders: openOrders.length,
                          cancelledOrders: cancelledOrders.length,
                          deliveredOrders: deliveredOrders.length,
                          deliveredRevenue: deliveredRevenue,
                          outstandingRevenue: outstandingRevenue,
                          averageDeliveredOrderValue:
                              averageDeliveredOrderValue,
                          categoryEntries: categoryEntries,
                          adminError: adminProvider.errorMessage,
                        ),
                      ),
                    ],
                  )
                : _DashboardContent(
                    isDesktop: false,
                    isTablet: isTablet,
                    orders: orders,
                    categoriesCount: categories.length,
                    totalProducts: products.length,
                    featuredProducts: featuredProducts,
                    activeProducts: activeProducts,
                    activeBanners: activeBanners,
                    openOrders: openOrders.length,
                    cancelledOrders: cancelledOrders.length,
                    deliveredOrders: deliveredOrders.length,
                    deliveredRevenue: deliveredRevenue,
                    outstandingRevenue: outstandingRevenue,
                    averageDeliveredOrderValue: averageDeliveredOrderValue,
                    categoryEntries: categoryEntries,
                    adminError: adminProvider.errorMessage,
                  ),
          ),
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.isDesktop,
    required this.isTablet,
    required this.orders,
    required this.categoriesCount,
    required this.totalProducts,
    required this.featuredProducts,
    required this.activeProducts,
    required this.activeBanners,
    required this.openOrders,
    required this.cancelledOrders,
    required this.deliveredOrders,
    required this.deliveredRevenue,
    required this.outstandingRevenue,
    required this.averageDeliveredOrderValue,
    required this.categoryEntries,
    required this.adminError,
  });

  final bool isDesktop;
  final bool isTablet;
  final List<OrderModel> orders;
  final int categoriesCount;
  final int totalProducts;
  final int featuredProducts;
  final int activeProducts;
  final int activeBanners;
  final int openOrders;
  final int cancelledOrders;
  final int deliveredOrders;
  final double deliveredRevenue;
  final double outstandingRevenue;
  final double averageDeliveredOrderValue;
  final List<MapEntry<String, int>> categoryEntries;
  final String? adminError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = isDesktop ? 36.0 : 18.0;
        final contentWidth = constraints.maxWidth - (padding * 2);
        final useTwoColumnPanels = contentWidth >= 1040;
        final recentOrders = orders.take(5).toList();
        final statusCards = [
          _MetricCard(
            title: 'Delivered revenue',
            value: 'Rs ${deliveredRevenue.toStringAsFixed(0)}',
            helper: '$deliveredOrders delivered orders',
            accent: _DashboardPalette.orange,
            icon: Icons.payments_outlined,
          ),
          _MetricCard(
            title: 'Open orders',
            value: '$openOrders',
            helper: 'Placed, confirmed, or shipped',
            accent: _DashboardPalette.blue,
            icon: Icons.local_shipping_outlined,
          ),
          _MetricCard(
            title: 'Catalog',
            value: '$totalProducts',
            helper: '$activeProducts active, $featuredProducts featured',
            accent: _DashboardPalette.green,
            icon: Icons.inventory_2_outlined,
          ),
          _MetricCard(
            title: 'Store setup',
            value: '$categoriesCount',
            helper: '$categoriesCount categories, $activeBanners live banners',
            accent: _DashboardPalette.rose,
            icon: Icons.storefront_outlined,
          ),
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, 28),
          children: [
            _DashboardTopBar(isDesktop: isDesktop),
            const SizedBox(height: 22),
            if (!isDesktop) ...[
              const _DashboardHeadline(),
              const SizedBox(height: 18),
            ],
            _ResponsiveMetricGrid(cards: statusCards, isDesktop: isDesktop),
            const SizedBox(height: 22),
            useTwoColumnPanels
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _RevenuePanel(
                          deliveredRevenue: deliveredRevenue,
                          outstandingRevenue: outstandingRevenue,
                          averageDeliveredOrderValue:
                              averageDeliveredOrderValue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _OrderStatusPanel(
                          openOrders: openOrders,
                          deliveredOrders: deliveredOrders,
                          cancelledOrders: cancelledOrders,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _RevenuePanel(
                        deliveredRevenue: deliveredRevenue,
                        outstandingRevenue: outstandingRevenue,
                        averageDeliveredOrderValue:
                            averageDeliveredOrderValue,
                      ),
                      const SizedBox(height: 16),
                      _OrderStatusPanel(
                        openOrders: openOrders,
                        deliveredOrders: deliveredOrders,
                        cancelledOrders: cancelledOrders,
                      ),
                    ],
                  ),
            const SizedBox(height: 22),
            useTwoColumnPanels
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _RecentOrdersPanel(orders: recentOrders),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _CategoryBreakdownPanel(
                          entries: categoryEntries,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _RecentOrdersPanel(orders: recentOrders),
                      const SizedBox(height: 16),
                      _CategoryBreakdownPanel(entries: categoryEntries),
                    ],
                  ),
            const SizedBox(height: 22),
            useTwoColumnPanels
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _QuickActionsPanel()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SystemHealthPanel(adminError: adminError),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const _QuickActionsPanel(),
                      const SizedBox(height: 16),
                      _SystemHealthPanel(adminError: adminError),
                    ],
                  ),
          ],
        );
      },
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar();

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        active: true,
      ),
      _SidebarItem(
        icon: Icons.receipt_long_outlined,
        label: 'Orders',
        onTap: () => Navigator.pushNamed(context, adminOrdersScreenRoute),
      ),
      _SidebarItem(
        icon: Icons.inventory_2_outlined,
        label: 'Products',
        onTap: () => Navigator.pushNamed(context, adminProductsScreenRoute),
      ),
      _SidebarItem(
        icon: Icons.category_outlined,
        label: 'Categories',
        onTap: () => Navigator.pushNamed(context, adminCategoriesScreenRoute),
      ),
      _SidebarItem(
        icon: Icons.view_carousel_outlined,
        label: 'Banners',
        onTap: () => Navigator.pushNamed(context, adminHomeBannerScreenRoute),
      ),
      _SidebarItem(
        icon: Icons.discount_outlined,
        label: 'Coupons',
        onTap: () => Navigator.pushNamed(context, adminCouponsScreenRoute),
      ),
      _SidebarItem(
        icon: Icons.local_shipping_outlined,
        label: 'Delivery',
        onTap: () =>
            Navigator.pushNamed(context, adminStoreSettingsScreenRoute),
      ),
      _SidebarItem(
        icon: Icons.view_stream_outlined,
        label: 'Home sections',
        onTap: () => Navigator.pushNamed(context, adminHomeSectionsScreenRoute),
      ),
    ];

    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF242A34)
                        : const Color(0xFFFFF7EC),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(11)),
                    child: Image.asset(
                      'assets/logo/petsworld_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PetsWorld',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: grandisExtendedFont,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Admin workspace',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const _DashboardHeadline(compact: true),
            const SizedBox(height: 24),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: item,
              ),
            ),
            const SizedBox(height: 24),
            _SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              onTap: () async {
                final authProvider = context.read<AuthProvider>();
                final navigator = Navigator.of(context);
                await authProvider.signOut();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AdminLoginScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeadline extends StatelessWidget {
  const _DashboardHeadline({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store control room',
          style: TextStyle(
            color: Theme.of(context).textTheme.headlineSmall?.color,
            fontSize: compact ? 22 : 34,
            fontWeight: FontWeight.w800,
            fontFamily: grandisExtendedFont,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Track fulfilled revenue, watch active orders, and keep the pet catalog healthy.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return isDesktop ? const _DashboardHeadline() : const SizedBox.shrink();
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  const _ResponsiveMetricGrid({required this.cards, required this.isDesktop});

  final List<Widget> cards;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1760
            ? 4
            : width >= 700
            ? 2
            : 1;
        final cardHeight = columns == 1
            ? 178.0
            : columns == 2
            ? 206.0
            : 236.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final String helper;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, color: accent),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: grandisExtendedFont,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.titleMedium?.color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: grandisExtendedFont,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenuePanel extends StatelessWidget {
  const _RevenuePanel({
    required this.deliveredRevenue,
    required this.outstandingRevenue,
    required this.averageDeliveredOrderValue,
  });

  final double deliveredRevenue;
  final double outstandingRevenue;
  final double averageDeliveredOrderValue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final series = [
      deliveredRevenue * 0.46,
      deliveredRevenue * 0.63,
      deliveredRevenue * 0.58,
      deliveredRevenue * 0.8,
      deliveredRevenue * 0.74,
      deliveredRevenue,
    ];

    return _Panel(
      title: 'Revenue analytics',
      subtitle: 'Only delivered orders contribute to revenue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 188,
            child: CustomPaint(
              painter: _RevenueChartPainter(
                values: series,
                backgroundColor: isDark
                    ? const Color(0xFF101720)
                    : _DashboardPalette.softSurface,
                gridColor: isDark
                    ? const Color(0xFF26313F)
                    : _DashboardPalette.border,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniStat(
                label: 'Delivered revenue',
                value: 'Rs ${deliveredRevenue.toStringAsFixed(0)}',
                color: _DashboardPalette.orange,
              ),
              _MiniStat(
                label: 'Open-order value',
                value: 'Rs ${outstandingRevenue.toStringAsFixed(0)}',
                color: _DashboardPalette.blue,
              ),
              _MiniStat(
                label: 'Avg delivered order',
                value: 'Rs ${averageDeliveredOrderValue.toStringAsFixed(0)}',
                color: _DashboardPalette.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderStatusPanel extends StatelessWidget {
  const _OrderStatusPanel({
    required this.openOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
  });

  final int openOrders;
  final int deliveredOrders;
  final int cancelledOrders;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.titleLarge?.color;
    final captionColor = Theme.of(context).textTheme.bodySmall?.color;

    return _Panel(
      title: 'Order completion',
      subtitle: 'See how many orders are active, delivered, or cancelled',
      child: Column(
        children: [
          SizedBox(
            width: 170,
            height: 170,
            child: CustomPaint(
              painter: _OrderStatusRingPainter(
                openOrders: openOrders,
                deliveredOrders: deliveredOrders,
                cancelledOrders: cancelledOrders,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${openOrders + deliveredOrders + cancelledOrders}',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'total orders',
                      style: TextStyle(color: captionColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _LegendRow(
            label: 'Open',
            value: '$openOrders',
            color: _DashboardPalette.blue,
          ),
          const SizedBox(height: 10),
          _LegendRow(
            label: 'Delivered',
            value: '$deliveredOrders',
            color: _DashboardPalette.orange,
          ),
          const SizedBox(height: 10),
          _LegendRow(
            label: 'Cancelled',
            value: '$cancelledOrders',
            color: _DashboardPalette.rose,
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersPanel extends StatelessWidget {
  const _RecentOrdersPanel({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent orders',
      subtitle: 'The latest orders entering your fulfillment pipeline',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Consumer<AdminProvider>(
              builder: (context, adminProvider, _) {
                return TextButton.icon(
                  onPressed:
                      adminProvider.orders.isEmpty || adminProvider.isSaving
                      ? null
                      : () async {
                          final result = await adminProvider.exportOrders();
                          if (!context.mounted) {
                            return;
                          }
                          final message = result == null
                              ? adminProvider.errorMessage ??
                                    'Unable to export orders.'
                              : result.location == null
                              ? 'Orders exported as ${result.fileName}.'
                              : 'Orders exported to ${result.location}.';
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export Excel'),
                );
              },
            ),
          ),
          if (orders.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No recent orders yet.',
                style: TextStyle(color: _DashboardPalette.muted),
              ),
            )
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.7)
                        : _DashboardPalette.softSurface,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE7CC),
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: _DashboardPalette.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.color,
                                fontWeight: FontWeight.w700,
                                fontFamily: grandisExtendedFont,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Order #${order.id}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${order.totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleSmall?.color,
                          fontWeight: FontWeight.w700,
                          fontFamily: grandisExtendedFont,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownPanel extends StatelessWidget {
  const _CategoryBreakdownPanel({required this.entries});

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return _Panel(
      title: 'Top categories',
      subtitle: 'Merchandising mix across the current catalog',
      child: entries.isEmpty
          ? const Text(
              'Add products and category insights will appear here.',
              style: TextStyle(color: _DashboardPalette.muted),
            )
          : Column(
              children: entries.take(6).map((entry) {
                final progress = total == 0 ? 0.0 : entry.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.color,
                                fontWeight: FontWeight.w700,
                                fontFamily: grandisExtendedFont,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: progress,
                          backgroundColor: Theme.of(context).dividerColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _DashboardPalette.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.inventory_2_outlined,
        label: 'Manage products',
        route: adminProductsScreenRoute,
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Review orders',
        route: adminOrdersScreenRoute,
      ),
      (
        icon: Icons.category_outlined,
        label: 'Manage categories',
        route: adminCategoriesScreenRoute,
      ),
      (
        icon: Icons.view_carousel_outlined,
        label: 'Edit banners',
        route: adminHomeBannerScreenRoute,
      ),
      (
        icon: Icons.discount_outlined,
        label: 'Manage coupons',
        route: adminCouponsScreenRoute,
      ),
      (
        icon: Icons.local_shipping_outlined,
        label: 'Delivery settings',
        route: adminStoreSettingsScreenRoute,
      ),
      (
        icon: Icons.view_stream_outlined,
        label: 'Home sections',
        route: adminHomeSectionsScreenRoute,
      ),
    ];

    return _Panel(
      title: 'Quick actions',
      subtitle: 'Jump straight into the most common admin tasks',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions
            .map(
              (action) => SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, action.route),
                  icon: Icon(action.icon),
                  label: Text(action.label),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SystemHealthPanel extends StatelessWidget {
  const _SystemHealthPanel({required this.adminError});

  final String? adminError;

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final paymentSettings = adminProvider.paymentSettings.mergeWith(
      currentPaymentSettings,
    );

    return _Panel(
      title: 'System health',
      subtitle: 'Configuration checks for the admin workspace',
      child: Column(
        children: [
          _HealthTile(
            title: 'Firebase',
            description: adminError == null
                ? 'Admin reads and writes are available for this account.'
                : adminError!,
            healthy: adminError == null,
          ),
          const SizedBox(height: 12),
          _HealthTile(
            title: 'Cloudinary',
            description: CloudinaryConfig.isConfigured
                ? 'Image uploads are configured.'
                : 'Add your Cloudinary cloud name and unsigned upload preset.',
            healthy: CloudinaryConfig.isConfigured,
          ),
          const SizedBox(height: 12),
          _HealthTile(
            title: 'Razorpay',
            description: paymentSettings.hasBackendBaseUrl
                ? paymentSettings.hasPublicKey
                    ? 'Runtime checkout settings are stored in the admin panel. Keep the matching Razorpay secret on your backend.'
                    : 'Backend checkout URL is saved. Add the public key ID here or return it from your backend order API.'
                : 'Add the Razorpay backend URL in Store settings so checkout can create and verify orders.',
            healthy: paymentSettings.hasBackendBaseUrl,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: grandisExtendedFont,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).textTheme.titleSmall?.color,
              fontWeight: FontWeight.w800,
              fontFamily: grandisExtendedFont,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).textTheme.titleSmall?.color,
            fontWeight: FontWeight.w700,
            fontFamily: grandisExtendedFont,
          ),
        ),
      ],
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.title,
    required this.description,
    required this.healthy,
  });

  final String title;
  final String description;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final color = healthy ? _DashboardPalette.green : _DashboardPalette.rose;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            healthy ? Icons.verified_outlined : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.titleSmall?.color,
                    fontWeight: FontWeight.w700,
                    fontFamily: grandisExtendedFont,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? _DashboardPalette.orange : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active
                  ? Colors.white
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Theme.of(context).textTheme.titleSmall?.color,
                fontWeight: FontWeight.w700,
                fontFamily: grandisExtendedFont,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter({
    required this.values,
    required this.backgroundColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color backgroundColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = _DashboardPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x44FF8C21), Color(0x10FF8C21), Color(0x00FF8C21)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.drawRRect(rect, backgroundPaint);

    for (var index = 1; index <= 3; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) {
      return;
    }

    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = math.max(1.0, maxValue - minValue);
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final normalized = (values[i] - minValue) / range;
      final x = stepX * i;
      final y = size.height - (normalized * (size.height - 26)) - 13;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _OrderStatusRingPainter extends CustomPainter {
  const _OrderStatusRingPainter({
    required this.openOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
  });

  final int openOrders;
  final int deliveredOrders;
  final int cancelledOrders;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);
    final total = math
        .max(1, openOrders + deliveredOrders + cancelledOrders)
        .toDouble();
    final basePaint = Paint()
      ..color = _DashboardPalette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final openPaint = Paint()
      ..color = _DashboardPalette.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final deliveredPaint = Paint()
      ..color = _DashboardPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final cancelledPaint = Paint()
      ..color = _DashboardPalette.rose
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    final openSweep = (openOrders / total) * math.pi * 2;
    final deliveredSweep = (deliveredOrders / total) * math.pi * 2;
    final cancelledSweep = (cancelledOrders / total) * math.pi * 2;
    var startAngle = -math.pi / 2;

    if (openSweep > 0) {
      canvas.drawArc(rect, startAngle, openSweep, false, openPaint);
      startAngle += openSweep;
    }
    if (deliveredSweep > 0) {
      canvas.drawArc(rect, startAngle, deliveredSweep, false, deliveredPaint);
      startAngle += deliveredSweep;
    }
    if (cancelledSweep > 0) {
      canvas.drawArc(rect, startAngle, cancelledSweep, false, cancelledPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrderStatusRingPainter oldDelegate) {
    return oldDelegate.openOrders != openOrders ||
        oldDelegate.deliveredOrders != deliveredOrders ||
        oldDelegate.cancelledOrders != cancelledOrders;
  }
}

class _DashboardPalette {
  static const softSurface = Color(0xFFFFFBF5);
  static const border = Color(0xFFE9DDCF);
  static const muted = Color(0xFF7F766D);
  static const orange = Color(0xFFFF8C21);
  static const blue = Color(0xFF4B6BFB);
  static const green = Color(0xFF278C69);
  static const rose = Color(0xFFD25C58);
}
