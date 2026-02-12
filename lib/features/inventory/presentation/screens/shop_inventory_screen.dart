import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/inventory/presentation/controllers/inventory_providers.dart';
import 'package:fitto/features/products/data/models/product.dart';

import 'product_inventory_detail_screen.dart';

enum InventoryFilter { all, inStock, outOfStock, inactive }

enum InventorySort { updated, mostAvailable, name }

class ShopInventoryScreen extends ConsumerStatefulWidget {
  const ShopInventoryScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<ShopInventoryScreen> createState() =>
      _ShopInventoryScreenState();
}

class _ShopInventoryScreenState extends ConsumerState<ShopInventoryScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  InventoryFilter _filter = InventoryFilter.all;
  InventorySort _sort = InventorySort.updated;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync =
        ref.watch(shopInventoryProductsProvider(widget.shopId));
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search product',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InventoryFilter>(
                    initialValue: _filter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Filter',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: InventoryFilter.all, child: Text('All')),
                      DropdownMenuItem(
                        value: InventoryFilter.inStock,
                        child: Text('In Stock'),
                      ),
                      DropdownMenuItem(
                        value: InventoryFilter.outOfStock,
                        child: Text('Out of Stock'),
                      ),
                      DropdownMenuItem(
                        value: InventoryFilter.inactive,
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _filter = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<InventorySort>(
                    initialValue: _sort,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Sort',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: InventorySort.updated,
                        child: Text('Updated'),
                      ),
                      DropdownMenuItem(
                        value: InventorySort.mostAvailable,
                        child: Text('Most available'),
                      ),
                      DropdownMenuItem(
                          value: InventorySort.name, child: Text('Name A-Z')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final filtered = _applyFilters(products);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      title: 'No products found',
                      subtitle: 'Try changing search or filter.',
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 52,
                              height: 52,
                              color: Colors.black12,
                              child: product.imageUrls.isEmpty
                                  ? const Icon(Icons.image_outlined)
                                  : Image.network(
                                      product.imageUrls.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.broken_image_outlined),
                                    ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _stockBadge(
                                    label:
                                        'Available ${product.totalAvailable}',
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  _stockBadge(
                                    label: 'Reserved ${product.totalReserved}',
                                    color: Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stock ${product.totalStock} - Variants ${product.variants.length}',
                              ),
                              const SizedBox(height: 4),
                              Text(product.isActive ? 'Active' : 'Inactive'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProductInventoryDetailScreen(
                                  productId: product.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const LoadingView(message: 'Loading inventory...'),
                error: (error, _) => ErrorView(
                  message: 'Failed to load inventory: $error',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Product> _applyFilters(List<Product> source) {
    var filtered = source.where((product) {
      if (_search.isEmpty) return true;
      return product.name.toLowerCase().contains(_search);
    }).toList();

    filtered = filtered.where((product) {
      switch (_filter) {
        case InventoryFilter.all:
          return true;
        case InventoryFilter.inStock:
          return product.totalAvailable > 0 && product.isActive;
        case InventoryFilter.outOfStock:
          return product.totalAvailable <= 0 && product.isActive;
        case InventoryFilter.inactive:
          return !product.isActive;
      }
    }).toList();

    switch (_sort) {
      case InventorySort.updated:
        filtered.sort((a, b) {
          final aTs = a.updatedAt?.millisecondsSinceEpoch ?? 0;
          final bTs = b.updatedAt?.millisecondsSinceEpoch ?? 0;
          return bTs.compareTo(aTs);
        });
        break;
      case InventorySort.mostAvailable:
        filtered.sort((a, b) => b.totalAvailable.compareTo(a.totalAvailable));
        break;
      case InventorySort.name:
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return filtered;
  }
}

Widget _stockBadge({
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
