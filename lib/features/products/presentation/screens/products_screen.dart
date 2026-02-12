import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/cart/presentation/screens/cart_screen.dart';
import 'package:fitto/features/shops/data/models/shop.dart';
import 'package:fitto/features/shops/presentation/controllers/shops_providers.dart';

import '../../data/repositories/products_repository.dart';
import '../controllers/products_providers.dart';
import 'product_details_screen.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key, this.initialShopId, this.title});

  final String? initialShopId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSort = ref.watch(productSortOptionProvider);
    final selectedCategory = ref.watch(selectedProductCategoryProvider);
    final selectedShop = ref.watch(selectedShopFilterProvider);
    final productsAsync = ref.watch(filteredProductsProvider(initialShopId));
    final categoriesAsync = ref.watch(productCategoriesProvider(initialShopId));
    final shopsByIdAsync = ref.watch(shopsByIdProvider);
    final isFixedShop = initialShopId != null && initialShopId!.isNotEmpty;

    final shopMap = shopsByIdAsync.valueOrNull;
    if (!isFixedShop &&
        selectedShop != null &&
        shopMap != null &&
        !shopMap.containsKey(selectedShop)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedShopFilterProvider.notifier).state = null;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Products'),
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
                  await ref.read(productsRepositoryProvider).seedSampleProducts();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample products created')),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by product name or category',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(productSearchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All categories'),
                          selected: selectedCategory == null,
                          onSelected: (_) {
                            ref.read(selectedProductCategoryProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(width: 8),
                        ...categoriesAsync.valueOrNull?.map((category) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(category),
                                  selected: selectedCategory == category,
                                  onSelected: (_) {
                                    ref.read(selectedProductCategoryProvider.notifier).state =
                                        selectedCategory == category ? null : category;
                                  },
                                ),
                              );
                            }) ??
                            const <Widget>[],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<ProductSortOption>(
                  value: selectedSort,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(productSortOptionProvider.notifier).state = value;
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ProductSortOption.newest,
                      child: Text('Newest'),
                    ),
                    DropdownMenuItem(
                      value: ProductSortOption.priceAsc,
                      child: Text('Price Asc'),
                    ),
                    DropdownMenuItem(
                      value: ProductSortOption.priceDesc,
                      child: Text('Price Desc'),
                    ),
                  ],
                ),
              ],
            ),
            if (!isFixedShop) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All shops'),
                      selected: selectedShop == null,
                      onSelected: (_) {
                        ref.read(selectedShopFilterProvider.notifier).state = null;
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._shopChips(
                      shopsByIdAsync: shopsByIdAsync,
                      selectedShopId: selectedShop,
                      onTap: (shopId) {
                        ref.read(selectedShopFilterProvider.notifier).state =
                            selectedShop == shopId ? null : shopId;
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return const EmptyState(
                      title: 'No products found',
                      subtitle: 'Change search/filter or seed sample products in debug mode.',
                    );
                  }

                  final shopMap = shopsByIdAsync.valueOrNull ?? const {};
                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final shopName = shopMap[product.shopId]?.name ?? 'Unknown shop';
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${product.price.toStringAsFixed(0)} ${product.currency}'),
                              if ((product.category ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Category: ${product.category}'),
                              ],
                              const SizedBox(height: 4),
                              Text('Shop: $shopName'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProductDetailsScreen(product: product),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingView(message: 'Loading products...'),
                error: (error, _) {
                  return ErrorView(
                    message: _friendlyFirestoreError('Failed to load products', error),
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

List<Widget> _shopChips({
  required AsyncValue<Map<String, Shop>> shopsByIdAsync,
  required String? selectedShopId,
  required void Function(String shopId) onTap,
}) {
  final shopMap = shopsByIdAsync.valueOrNull ?? const <String, Shop>{};
  final chips = <Widget>[];
  for (final entry in shopMap.entries) {
    final shop = entry.value;
    chips.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(shop.name),
          selected: selectedShopId == entry.key,
          onSelected: (_) => onTap(entry.key),
        ),
      ),
    );
  }
  return chips;
}

String _friendlyFirestoreError(String prefix, Object error) {
  final raw = error.toString();
  if (raw.toLowerCase().contains('index')) {
    return '$prefix. Firestore index may be missing for this query.';
  }
  return '$prefix: $error';
}
