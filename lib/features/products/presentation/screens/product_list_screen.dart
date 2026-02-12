import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/core/widgets/section_title.dart';
import 'package:fitto/features/products/data/models/product_model.dart';
import 'package:fitto/features/products/presentation/controllers/product_providers.dart';
import 'package:fitto/features/products/presentation/screens/product_detail_screen.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key, this.shopId, this.title});

  final String? shopId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productSearchQueryProvider);
    final selectedCategory = ref.watch(selectedProductCategoryProvider);
    final sort = ref.watch(productSortProvider);
    final productsAsync = shopId == null
        ? ref.watch(filteredGlobalProductsProvider)
        : ref.watch(filteredShopProductsProvider(shopId!));
    final allProductsAsync =
        shopId == null ? ref.watch(globalProductsProvider) : ref.watch(shopProductsProvider(shopId!));

    final categories = _extractCategories(allProductsAsync);

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? (shopId == null ? 'All Products' : 'Shop Products')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Browse Products'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by title...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  ref.read(productSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: selectedCategory == null,
                          onSelected: (_) {
                            ref.read(selectedProductCategoryProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(width: 8),
                        ...categories.map((category) {
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
                        }),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<ProductSort>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  initialValue: sort,
                  onSelected: (value) {
                    ref.read(productSortProvider.notifier).state = value;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: ProductSort.none,
                      child: Text('No sort'),
                    ),
                    PopupMenuItem(
                      value: ProductSort.priceLowToHigh,
                      child: Text('Price: low to high'),
                    ),
                    PopupMenuItem(
                      value: ProductSort.priceHighToLow,
                      child: Text('Price: high to low'),
                    ),
                  ],
                ),
              ],
            ),
            if (query.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Search: "$query"'),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return const EmptyState(
                      title: 'No products found',
                      subtitle: 'Try changing search text, category, or sort.',
                    );
                  }

                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductCard(product: product);
                    },
                  );
                },
                loading: () => const LoadingView(message: 'Loading products...'),
                error: (e, _) => ErrorView(message: 'Failed to load products: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _extractCategories(AsyncValue<List<ProductModel>> value) {
    final products = value.valueOrNull ?? const <ProductModel>[];
    final set = <String>{};
    for (final product in products) {
      if (product.category.trim().isNotEmpty) {
        set.add(product.category.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(product.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${product.price} ${product.currency}'),
            const SizedBox(height: 6),
            Chip(
              label: Text(product.category),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(productId: product.productId),
            ),
          );
        },
      ),
    );
  }
}
