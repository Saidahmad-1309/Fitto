import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/cart/presentation/screens/cart_screen.dart';

import '../controllers/orders_providers.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CartScreen(),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Cart',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return const EmptyState(
                title: 'No orders yet',
                subtitle: 'Checkout a cart to create your first order.',
              );
            }
            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = orders[index];
                final effectiveStatus = order.resolvedStatus;
                return Card(
                  child: ListTile(
                    title:
                        Text('Order ${order.id.substring(0, 6).toUpperCase()}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Status: $effectiveStatus'),
                        const SizedBox(height: 4),
                        Text('Payment: ${order.paymentStatus}'),
                        const SizedBox(height: 4),
                        Text(
                            'Subtotal: ${order.subtotal.toStringAsFixed(0)} UZS'),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OrderDetailScreen(orderId: order.id),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
          loading: () => const LoadingView(message: 'Loading orders...'),
          error: (e, _) => ErrorView(message: 'Failed to load orders: $e'),
        ),
      ),
    );
  }
}
