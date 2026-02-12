import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/constants/product_sizes.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/cart/presentation/controllers/cart_providers.dart';
import 'package:fitto/features/shops/presentation/controllers/shops_providers.dart';

import '../../data/models/product.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late String _selectedSize;

  @override
  void initState() {
    super.initState();
    _selectedSize = _initialSize(widget.product);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final availableSizes = product.sizes.where(isEligibleProductSize).toList();
    if (availableSizes.isNotEmpty &&
        !availableSizes.contains(_selectedSize)) {
      _selectedSize = availableSizes.first;
    }
    final selectedAvailable = product.availableForSize(_selectedSize);
    final shopsAsync = ref.watch(shopsByIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: shopsAsync.when(
          data: (shops) {
            final shopName = shops[product.shopId]?.name ?? 'Unknown shop';
            return ListView(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Center(child: Icon(Icons.image_outlined, size: 48)),
                ),
                const SizedBox(height: 16),
                Text(
                  product.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.price.toStringAsFixed(0)} ${product.currency}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if ((product.category ?? '').isNotEmpty)
                  Text('Category: ${product.category}'),
                const SizedBox(height: 6),
                Text('Shop: $shopName'),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  (product.description ?? '').isNotEmpty
                      ? product.description!
                      : 'No description provided.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Size Availability',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableSizes.map((size) {
                    final available = product.availableForSize(size);
                    final isSelected = _selectedSize == size;
                    return ChoiceChip(
                      label: Text('$size ($available)'),
                      selected: isSelected,
                      onSelected: available <= 0
                          ? null
                          : (_) {
                              setState(() {
                                _selectedSize = size;
                              });
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedAvailable > 0
                      ? 'Available now: $selectedAvailable'
                      : 'Out of stock for $_selectedSize',
                  style: TextStyle(
                    color: selectedAvailable > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (selectedAvailable > 0 && selectedAvailable <= 3) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Only $selectedAvailable left',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: selectedAvailable <= 0
                      ? null
                      : () async {
                          await ref.read(cartControllerProvider).addToCart(
                                productId: product.id,
                                nameSnapshot: product.name,
                                priceSnapshot: product.price,
                                shopId: product.shopId,
                                size: _selectedSize,
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added $_selectedSize to cart'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    selectedAvailable <= 0 ? 'Out of stock' : 'Add to Cart',
                  ),
                ),
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading product...'),
          error: (e, _) => ErrorView(message: 'Failed to load shops: $e'),
        ),
      ),
    );
  }

  String _initialSize(Product product) {
    final sizes = product.sizes.where(isEligibleProductSize);
    for (final size in sizes) {
      if (product.availableForSize(size) > 0) return size;
    }
    return sizes.isNotEmpty ? sizes.first : 'M';
  }
}
