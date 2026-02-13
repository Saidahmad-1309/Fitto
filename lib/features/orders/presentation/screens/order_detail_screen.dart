import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';

import '../controllers/orders_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: orderAsync.when(
          data: (order) {
            if (order == null) {
              return const Center(child: Text('Order not found.'));
            }
            final effectiveStatus = order.resolvedStatus;
            return ListView(
              children: [
                Text('Status: $effectiveStatus',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Payment: ${_toLabel(order.paymentMethod)}'),
                const SizedBox(height: 4),
                Text('Payment status: ${order.paymentStatus}'),
                const SizedBox(height: 8),
                Text('Delivery Address: ${order.deliveryAddress}'),
                const SizedBox(height: 12),
                const Text(
                  'Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ..._buildOrderTimeline(effectiveStatus),
                const SizedBox(height: 12),
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) {
                  return Card(
                    child: ListTile(
                      title: Text(item.nameSnapshot),
                      subtitle: Text('Qty: ${item.qty}  |  Size: ${item.size}'),
                      trailing: Text(
                        (item.priceSnapshot * item.qty).toStringAsFixed(0),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text(
                  'Subtotal: ${order.subtotal.toStringAsFixed(0)} UZS',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading order...'),
          error: (e, _) => ErrorView(message: 'Failed to load order: $e'),
        ),
      ),
    );
  }

  String _toLabel(String method) {
    return switch (method) {
      'online_payment' => 'Online payment',
      'store_pickup' => 'Store pickup',
      _ => method,
    };
  }

  List<Widget> _buildOrderTimeline(String status) {
    final normalized = status.toLowerCase();
    final steps = <String>[
      'pending',
      'accepted',
      'paid',
      'preparing',
      'delivered',
    ];
    final labels = <String, String>{
      'pending': 'Order created',
      'accepted': 'Accepted by shop',
      'paid': 'Paid',
      'preparing': 'Preparing',
      'delivered': 'Delivered',
    };

    if (normalized == 'rejected' || normalized == 'canceled') {
      return [
        _timelineTile('Order created', _StepState.done),
        _timelineTile(
          normalized == 'rejected' ? 'Rejected' : 'Canceled',
          _StepState.current,
        ),
      ];
    }

    final timelineStatus = normalized == 'processing' ? 'accepted' : normalized;
    final currentIndex =
        steps.indexOf(timelineStatus).clamp(0, steps.length - 1);
    final items = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final state = i < currentIndex
          ? _StepState.done
          : (i == currentIndex ? _StepState.current : _StepState.pending);
      items.add(_timelineTile(labels[steps[i]] ?? steps[i], state));
    }
    return items;
  }

  Widget _timelineTile(String label, _StepState state) {
    final icon = switch (state) {
      _StepState.done => Icons.check_circle,
      _StepState.current => Icons.radio_button_checked,
      _StepState.pending => Icons.radio_button_unchecked,
    };
    final color = switch (state) {
      _StepState.done => Colors.green,
      _StepState.current => Colors.blue,
      _StepState.pending => Colors.grey,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
    );
  }
}

enum _StepState { done, current, pending }
