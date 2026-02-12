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
            final effectiveStatus =
                order.status.trim().isEmpty ? 'pending' : order.status;
            return ListView(
              children: [
                Text(
                  'Status: $effectiveStatus',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('Delivery Address: ${order.deliveryAddress}'),
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
}
