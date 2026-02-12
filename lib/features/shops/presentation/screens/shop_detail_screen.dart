import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/core/widgets/section_title.dart';
import 'package:fitto/features/products/presentation/screens/product_list_screen.dart';
import 'package:fitto/features/shops/presentation/controllers/shop_providers.dart';

class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopDetailProvider(shopId));

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: shopAsync.when(
          data: (shop) {
            if (shop == null) {
              return const Center(child: Text('Shop not found.'));
            }

            return ListView(
              children: [
                SectionTitle(title: shop.name),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('City: ${shop.city}'),
                        const SizedBox(height: 8),
                        Text('Address: ${shop.address}'),
                        const SizedBox(height: 8),
                        Text('Opening Hours: ${shop.openingHours}'),
                        const SizedBox(height: 8),
                        Text(
                          'Delivery: ${shop.deliveryAvailable ? 'Available' : 'Not available'}',
                        ),
                        if ((shop.phone ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Phone: ${shop.phone}'),
                        ],
                        if ((shop.instagram ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Instagram: ${shop.instagram}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => ProductListScreen(
                              shopId: shop.shopId,
                              title: '${shop.name} Products',
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Browse Products'),
                ),
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading shop details...'),
          error: (e, _) => ErrorView(message: 'Failed to load shop: $e'),
        ),
      ),
    );
  }
}
