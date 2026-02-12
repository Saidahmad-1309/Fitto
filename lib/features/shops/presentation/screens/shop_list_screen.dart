import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/core/widgets/section_title.dart';
import 'package:fitto/features/shops/presentation/controllers/shop_providers.dart';
import 'package:fitto/features/shops/presentation/screens/shop_detail_screen.dart';

class ShopListScreen extends ConsumerWidget {
  const ShopListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
        actions: [
          if (kDebugMode)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(shopRepositoryProvider).seedSampleData();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample shops and products seeded.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Seeding failed: $e')),
                  );
                }
              },
              child: const Text('Seed Sample Data'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: shopsAsync.when(
          data: (shops) {
            if (shops.isEmpty) {
              return const EmptyState(
                title: 'No shops found',
                subtitle: 'Use "Seed Sample Data" in debug mode to add sample records.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Local Shops'),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          title: Text(shop.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(shop.city),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (shop.deliveryAvailable)
                                    const Chip(
                                      label: Text('Delivery'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  Chip(
                                    label: Text(shop.openingHours),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShopDetailScreen(shopId: shop.shopId),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading shops...'),
          error: (e, _) => ErrorView(message: 'Failed to load shops: $e'),
        ),
      ),
    );
  }
}
