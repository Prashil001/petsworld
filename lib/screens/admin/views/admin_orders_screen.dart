import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/providers/admin_provider.dart';
import 'package:shop/providers/auth_provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final adminProvider = context.watch<AdminProvider>();

    if (authProvider.isAdmin &&
        adminProvider.orders.isEmpty &&
        !adminProvider.isLoading) {
      Future.microtask(adminProvider.loadAdminData);
    }

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Orders')),
        body: const Center(
          child: Text('Admin access is required to manage orders.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: adminProvider.orders.isEmpty || adminProvider.isSaving
                  ? null
                  : () => _exportOrders(context),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AdminProvider>().loadAdminData(),
        child: adminProvider.orders.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(defaultPadding),
                children: const [
                  SizedBox(height: defaultPadding * 4),
                  Center(
                    child: Text(
                      'No orders found yet. Orders will appear here after checkout starts creating them.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  final horizontalPadding = isWide ? 28.0 : defaultPadding;
                  final orders = adminProvider.orders;
                  final deliveredRevenue = orders
                      .where((order) => order.isDelivered)
                      .fold<double>(0, (sum, order) => sum + order.totalPrice);
                  final pendingOrders = orders
                      .where((order) => !order.isCompleted)
                      .length;
                  final cancelledOrders = orders
                      .where((order) => order.isCancelled)
                      .length;
                  final filteredOrders = orders.where((order) {
                    if (_selectedStatus == 'all') return true;
                    if (_selectedStatus == 'open') return !order.isCompleted;
                    if (_selectedStatus == 'delivered') return order.isDelivered;
                    if (_selectedStatus == 'cancelled') return order.isCancelled;
                    return true;
                  }).toList();

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      28,
                    ),
                    children: [
                      _OrdersHero(
                        totalOrders: orders.length,
                        pendingOrders: pendingOrders,
                        cancelledOrders: cancelledOrders,
                        deliveredRevenue: deliveredRevenue,
                        onExport: adminProvider.isSaving
                            ? null
                            : () => _exportOrders(context),
                      ),
                      const SizedBox(height: 18),
                      _OrdersOverview(
                        totalOrders: orders.length,
                        pendingOrders: pendingOrders,
                        cancelledOrders: cancelledOrders,
                        deliveredRevenue: deliveredRevenue,
                        isWide: isWide,
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _OrderStatusFilterChip(
                              label: 'All (${orders.length})',
                              isSelected: _selectedStatus == 'all',
                              onTap: () => setState(() => _selectedStatus = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _OrderStatusFilterChip(
                              label: 'Open ($pendingOrders)',
                              isSelected: _selectedStatus == 'open',
                              onTap: () => setState(() => _selectedStatus = 'open'),
                            ),
                            const SizedBox(width: 8),
                            _OrderStatusFilterChip(
                              label: 'Delivered (${orders.where((o) => o.isDelivered).length})',
                              isSelected: _selectedStatus == 'delivered',
                              onTap: () => setState(() => _selectedStatus = 'delivered'),
                            ),
                            const SizedBox(width: 8),
                            _OrderStatusFilterChip(
                              label: 'Cancelled ($cancelledOrders)',
                              isSelected: _selectedStatus == 'cancelled',
                              onTap: () => setState(() => _selectedStatus = 'cancelled'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (filteredOrders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'No orders found for the selected filter.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...filteredOrders.map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _AdminOrderCard(
                              order: order,
                              isSaving: adminProvider.isSaving,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<void> _exportOrders(BuildContext context) async {
    final result = await context.read<AdminProvider>().exportOrders();
    if (!context.mounted) {
      return;
    }

    final provider = context.read<AdminProvider>();
    final message = result == null
        ? provider.errorMessage ?? 'Unable to export orders.'
        : result.location == null
        ? 'Orders exported as ${result.fileName}.'
        : 'Orders exported to ${result.location}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _OrderStatusFilterChip extends StatelessWidget {
  const _OrderStatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
      ),
    );
  }
}

class _OrdersHero extends StatelessWidget {
  const _OrdersHero({
    required this.totalOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.deliveredRevenue,
    required this.onExport,
  });

  final int totalOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final double deliveredRevenue;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1B2330), Color(0xFF262037)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFF6E7), Color(0xFFF9E5C5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final heroBorderColor = isDark
        ? const Color(0xFF2E3950)
        : const Color(0xFFEBD4A8);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: heroGradient,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        border: Border.all(color: heroBorderColor),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order operations',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review every order, update fulfilment status, and export the latest order sheet for bookkeeping.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroBadge(label: '$totalOrders total'),
                    _HeroBadge(label: '$pendingOrders open'),
                    _HeroBadge(label: '$cancelledOrders cancelled'),
                    _HeroBadge(
                      label: 'Rs ${deliveredRevenue.toStringAsFixed(0)} delivered',
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export Excel'),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.82),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.28),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrdersOverview extends StatelessWidget {
  const _OrdersOverview({
    required this.totalOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.deliveredRevenue,
    required this.isWide,
  });

  final int totalOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final double deliveredRevenue;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OverviewTile(
        label: 'Total orders',
        value: '$totalOrders',
        color: const Color(0xFF4E6AF3),
        icon: Icons.receipt_long_outlined,
      ),
      _OverviewTile(
        label: 'Open orders',
        value: '$pendingOrders',
        color: const Color(0xFFE58C2D),
        icon: Icons.local_shipping_outlined,
      ),
      _OverviewTile(
        label: 'Cancelled',
        value: '$cancelledOrders',
        color: const Color(0xFFD14C4C),
        icon: Icons.cancel_outlined,
      ),
      _OverviewTile(
        label: 'Delivered revenue',
        value: 'Rs ${deliveredRevenue.toStringAsFixed(0)}',
        color: const Color(0xFF27935F),
        icon: Icons.payments_outlined,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: card == cards.last ? 0 : 14,
                  ),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: cards
          .map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
          )
          .toList(),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151D26)
            : Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(
          color: isDark
              ? const Color(0xFF253041)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({
    required this.order,
    required this.isSaving,
  });

  final OrderModel order;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D26) : Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? const Color(0xFF253041)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            spacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildDateLabel(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusPill(
                    label: _statusLabel(order.orderStatus),
                    color: _statusColor(order.orderStatus),
                  ),
                  _StatusPill(
                    label: _paymentMethodLabel(order.paymentMethod),
                    color: const Color(0xFF4E6AF3),
                  ),
                  _StatusPill(
                    label: _paymentStatusLabel(order.paymentStatus),
                    color: _paymentColor(order.paymentStatus),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CustomerPanel(order: order)),
                    const SizedBox(width: 16),
                    Expanded(child: _AddressPanel(order: order)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TotalsAndActionsPanel(
                        order: order,
                        isSaving: isSaving,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _CustomerPanel(order: order),
                    const SizedBox(height: 14),
                    _AddressPanel(order: order),
                    const SizedBox(height: 14),
                    _TotalsAndActionsPanel(order: order, isSaving: isSaving),
                  ],
                ),
          const SizedBox(height: 18),
          Text(
            'Items',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111821)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF222C3A)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Product ID: ${item.productId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('x${item.quantity}'),
                    const SizedBox(width: 16),
                    Text(
                      'Rs ${item.lineTotal.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleSmall,
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

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return 'Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return const Color(0xFF6E6E73);
      case OrderStatus.confirmed:
        return const Color(0xFF4E6AF3);
      case OrderStatus.shipped:
        return const Color(0xFFE58C2D);
      case OrderStatus.delivered:
        return const Color(0xFF27935F);
      case OrderStatus.cancelled:
        return const Color(0xFFD14C4C);
    }
  }

  String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cod:
        return 'Cash on Delivery';
      case PaymentMethod.razorpay:
        return 'Razorpay';
    }
  }

  String _paymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Payment pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment failed';
    }
  }

  Color _paymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return const Color(0xFFE58C2D);
      case PaymentStatus.paid:
        return const Color(0xFF27935F);
      case PaymentStatus.failed:
        return const Color(0xFFD14C4C);
    }
  }

  String _buildDateLabel(DateTime? date) {
    if (date == null) {
      return 'Created recently';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute';
  }
}

class _CustomerPanel extends StatelessWidget {
  const _CustomerPanel({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Name', value: order.customerName),
          _InfoRow(label: 'Email', value: order.userEmail.isEmpty ? 'Not provided' : order.userEmail),
          _InfoRow(label: 'Phone', value: order.phoneNumber),
          _InfoRow(label: 'User ID', value: order.userId),
        ],
      ),
    );
  }
}

class _AddressPanel extends StatelessWidget {
  const _AddressPanel({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      title: 'Delivery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Recipient', value: order.deliveryAddress.fullName),
          _InfoRow(label: 'Phone', value: order.deliveryAddress.phone),
          _InfoRow(label: 'Address', value: order.deliveryAddress.fullAddress),
        ],
      ),
    );
  }
}

class _TotalsAndActionsPanel extends StatelessWidget {
  const _TotalsAndActionsPanel({
    required this.order,
    required this.isSaving,
  });

  final OrderModel order;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      title: 'Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: 'Subtotal',
            value: 'Rs ${order.subtotal.toStringAsFixed(0)}',
          ),
          _InfoRow(
            label: 'Delivery',
            value: 'Rs ${order.deliveryCharge.toStringAsFixed(0)}',
          ),
          _InfoRow(
            label: 'Total',
            value: 'Rs ${order.totalPrice.toStringAsFixed(0)}',
          ),
          _InfoRow(
            label: 'Items',
            value: '${order.totalItems}',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isSaving ? null : () => _downloadInvoice(context),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Generate invoice'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OrderStatus>(
            initialValue: order.orderStatus,
            decoration: const InputDecoration(labelText: 'Order status'),
            items: OrderStatus.values
                .map(
                  (status) => DropdownMenuItem<OrderStatus>(
                    value: status,
                    child: Text(status.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: isSaving || order.isCompleted
                ? null
                : (status) {
                    if (status == null || status == order.orderStatus) {
                      return;
                    }
                    context.read<AdminProvider>().updateOrderStatus(order.id, status);
                  },
          ),
          if (order.isCompleted) ...[
            const SizedBox(height: 8),
            Text(
              'Delivered and cancelled orders are locked to protect reporting accuracy.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context) async {
    final result = await context.read<AdminProvider>().exportInvoice(order);
    if (!context.mounted) {
      return;
    }

    final provider = context.read<AdminProvider>();
    final message = result == null
        ? provider.errorMessage ?? 'Unable to generate invoice.'
        : result.location == null
        ? 'Invoice saved as ${result.fileName}.'
        : 'Invoice saved to ${result.location}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111821)
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: isDark ? const Color(0xFF222C3A) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
