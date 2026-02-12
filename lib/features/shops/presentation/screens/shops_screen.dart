import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/cart/presentation/screens/cart_screen.dart';
import 'package:fitto/features/products/presentation/screens/products_screen.dart';

import '../controllers/shops_providers.dart';

class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(filteredShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
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
          if (kDebugMode)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(shopsRepositoryProvider).seedSampleShops();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample shops created')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Seed failed: $e')),
                  );
                }
              },
              child: const Text('Seed'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search shop by name or city',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(shopsSearchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: shopsAsync.when(
                data: (shops) {
                  if (shops.isEmpty) {
                    return const EmptyState(
                      title: 'No shops found',
                      subtitle: 'Try changing the search or seed sample shops in debug mode.',
                    );
                  }

                  return ListView.separated(
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          title: Text(
                            shop.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((shop.city ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(shop.city!),
                              ],
                              if ((shop.description ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  shop.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => ProductsScreen(
                                      initialShopId: shop.id,
                                      title: '${shop.name} Products',
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingView(message: 'Loading shops...'),
                error: (error, _) {
                  return ErrorView(
                    message: _friendlyFirestoreError('Failed to load shops', error),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyFirestoreError(String prefix, Object error) {
  final raw = error.toString();
  if (raw.toLowerCase().contains('index')) {
    return '$prefix. Firestore index may be missing for this query.';
  }
  return '$prefix: $error';
}
