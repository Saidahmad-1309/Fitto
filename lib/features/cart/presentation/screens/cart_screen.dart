import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/cart/presentation/controllers/cart_providers.dart';
import 'package:fitto/features/orders/presentation/controllers/orders_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(cartControllerProvider).clearCart();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: cartAsync.when(
          data: (cart) {
            if (cart == null || cart.isEmpty) {
              return const EmptyState(
                title: 'Your cart is empty',
                subtitle: 'Add items from Products to get started.',
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          title: Text(item.nameSnapshot),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                  '${item.priceSnapshot.toStringAsFixed(0)} UZS'),
                              const SizedBox(height: 4),
                              Text('Size: ${item.size}'),
                              const SizedBox(height: 4),
                              Text('Qty: ${item.qty}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () async {
                                  await ref
                                      .read(cartControllerProvider)
                                      .updateQty(
                                        productId: item.productId,
                                        size: item.size,
                                        qty: item.qty - 1,
                                      );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () async {
                                  await ref
                                      .read(cartControllerProvider)
                                      .updateQty(
                                        productId: item.productId,
                                        size: item.size,
                                        qty: item.qty + 1,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${cart.subtotal.toStringAsFixed(0)} UZS',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final paymentMethod = await _showCheckoutDialog(context);
                    if (paymentMethod == null || !context.mounted) return;
                    final success = await ref
                        .read(ordersControllerProvider)
                        .checkoutFromCartWithPaymentMethod(
                          cart,
                          paymentMethod: paymentMethod,
                        );
                    if (!context.mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Order created successfully.')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Checkout failed. Try again.')),
                      );
                    }
                  },
                  child: const Text('Checkout'),
                ),
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading cart...'),
          error: (e, _) => ErrorView(message: 'Failed to load cart: $e'),
        ),
      ),
    );
  }

  Future<String?> _showCheckoutDialog(BuildContext context) {
    const methods = <String, String>{
      'cash_on_delivery': 'Cash on delivery',
      'card_on_delivery': 'Card on delivery',
      'store_pickup': 'Store pickup',
    };

    var selected = 'cash_on_delivery';
    var agreed = false;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirm Checkout'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select payment method'),
                  const SizedBox(height: 8),
                  ...methods.entries.map((entry) {
                    return RadioListTile<String>(
                      value: entry.key,
                      groupValue: selected,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selected = value);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: agreed,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I confirm this checkout'),
                    onChanged: (value) {
                      setState(() => agreed = value ?? false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: agreed
                      ? () => Navigator.of(dialogContext).pop(selected)
                      : null,
                  child: const Text('Place Order'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
