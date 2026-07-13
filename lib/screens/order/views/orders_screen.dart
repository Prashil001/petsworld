import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop/constants.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/core/widgets/app_loading_indicator.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/order_provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final pendingOrders = orderProvider.pendingOrders;
    final completedOrders = orderProvider.completedOrders;
    final currentUserId = authProvider.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: orderProvider.isLoading
          ? const AppLoadingIndicator(message: 'Loading your orders...')
          : orderProvider.errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Text(
                  orderProvider.errorMessage!,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : orderProvider.orders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Text(
                  'No orders yet. Orders from checkout will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<OrderProvider>().loadUserOrders(currentUserId),
              child: ListView(
                padding: const EdgeInsets.all(defaultPadding),
                children: [
                  _OrderGroup(
                    title: 'Open Orders',
                    subtitle: 'Orders that are still being processed',
                    orders: pendingOrders,
                    currentUserId: currentUserId,
                  ),
                  const SizedBox(height: defaultPadding),
                  _OrderGroup(
                    title: 'History',
                    subtitle: 'Delivered and cancelled orders',
                    orders: completedOrders,
                    currentUserId: currentUserId,
                  ),
                ],
              ),
            ),
    );
  }
}

class _OrderGroup extends StatelessWidget {
  const _OrderGroup({
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.currentUserId,
  });

  final String title;
  final String subtitle;
  final List<OrderModel> orders;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: defaultPadding),
        if (orders.isEmpty)
          _OrderSectionEmptyState(
            message: title == 'Open Orders'
                ? 'No active orders right now.'
                : 'Delivered and cancelled orders will appear here.',
          )
        else
          ...orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: defaultPadding),
              child: _OrderCard(
                order: order,
                currentUserId: currentUserId,
              ),
            ),
          ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.currentUserId,
  });

  final OrderModel order;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final statusTone = _statusTone(order.orderStatus);
    final paymentTone = _paymentTone(order.paymentStatus);

    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildCreatedLabel(order),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _Pill(
                label: _statusLabel(order.orderStatus),
                color: statusTone,
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label: _paymentLabel(order.paymentMethod),
                color: const Color(0xFF4E6AF3),
              ),
              _Pill(
                label: _paymentStatusLabel(order.paymentStatus),
                color: paymentTone,
              ),
              _Pill(
                label: '${order.totalItems} item${order.totalItems == 1 ? '' : 's'}',
                color: const Color(0xFF7A59C8),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          ...order.items.take(3).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('x${item.quantity}'),
                  const SizedBox(width: 12),
                  Text('Rs ${item.lineTotal.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
          if (order.items.length > 3) ...[
            const SizedBox(height: 2),
            Text(
              '+${order.items.length - 3} more items',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: defaultPadding),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery address',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Text(order.address, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: defaultPadding),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Total: Rs ${order.totalPrice.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: () => _downloadInvoice(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Invoice'),
              ),
              if (order.canUserCancel)
                OutlinedButton(
                  onPressed: () => _cancelOrder(context),
                  child: const Text('Cancel order'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel order?'),
          content: const Text(
            'You can cancel an order only before it is shipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep order'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final success = await context.read<OrderProvider>().cancelOrder(
      orderId: order.id,
      userId: currentUserId,
    );
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Order cancelled successfully.'
              : context.read<OrderProvider>().errorMessage ??
                    'Unable to cancel this order.',
        ),
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context) async {
    final result = await context.read<OrderProvider>().saveInvoice(order);
    if (!context.mounted) {
      return;
    }

    final provider = context.read<OrderProvider>();
    final message = result == null
        ? provider.invoiceErrorMessage ?? 'Unable to save invoice right now.'
        : result.location == null
        ? 'Invoice saved as ${result.fileName}.'
        : 'Invoice saved to ${result.location}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _statusTone(OrderStatus status) {
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

  Color _paymentTone(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return const Color(0xFFE58C2D);
      case PaymentStatus.paid:
        return const Color(0xFF27935F);
      case PaymentStatus.failed:
        return const Color(0xFFD14C4C);
    }
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

  String _paymentLabel(PaymentMethod method) {
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

  String _buildCreatedLabel(OrderModel order) {
    final createdAt = order.createdAt;
    if (createdAt == null) {
      return 'Placed recently';
    }
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();
    return 'Placed on $day/$month/$year';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

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

class _OrderSectionEmptyState extends StatelessWidget {
  const _OrderSectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(message),
    );
  }
}
