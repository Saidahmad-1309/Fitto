import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/constants/product_sizes.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/products/presentation/controllers/product_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: productAsync.when(
          data: (product) {
            if (product == null) {
              return const Center(child: Text('Product not found.'));
            }

            final normalizedSizes = product.availableSizes
                .map((size) => normalizeProductSize(size, fallback: 'M'))
                .where(isEligibleProductSize)
                .toSet()
                .toList(growable: false);

            return ListView(
              children: [
                Text(
                  product.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.price} ${product.currency}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(product.description),
                const SizedBox(height: 16),
                Text(
                  'Category: ${product.category}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Available Sizes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...normalizedSizes.map((size) => Chip(label: Text(size))),
                    if (normalizedSizes.isEmpty) const Chip(label: Text('-')),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available Colors',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...product.availableColors.map((color) => Chip(label: Text(color))),
                    if (product.availableColors.isEmpty) const Chip(label: Text('-')),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Stock: ${product.stock}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading product details...'),
          error: (e, _) => ErrorView(message: 'Failed to load product: $e'),
        ),
      ),
    );
  }
}
