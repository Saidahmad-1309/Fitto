import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/constants/product_sizes.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/inventory/presentation/screens/shop_inventory_screen.dart';
import 'package:fitto/features/products/data/models/product.dart';
import 'package:fitto/features/products/presentation/controllers/products_providers.dart';
import 'package:fitto/features/shop_onboarding/presentation/screens/shop_orders_screen.dart';

import '../controllers/shop_onboarding_providers.dart';

class ShopPortalScreen extends ConsumerStatefulWidget {
  const ShopPortalScreen({super.key});

  @override
  ConsumerState<ShopPortalScreen> createState() => _ShopPortalScreenState();
}

class _ShopPortalScreenState extends ConsumerState<ShopPortalScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedSizes = <String>{'M'};

  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final linkAsync = ref.watch(shopUserLinkProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('My Shop Portal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: linkAsync.when(
          data: (link) {
            if (link == null || link.shopId.isEmpty) {
              return const EmptyState(
                title: 'No approved shop yet',
                subtitle:
                    'Your application must be approved before managing products.',
              );
            }

            final productsAsync = ref.watch(shopProductsProvider(link.shopId));
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop ID: ${link.shopId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ShopInventoryScreen(shopId: link.shopId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Inventory'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ShopOrdersScreen(shopId: link.shopId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Orders'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAddProductForm(link.shopId),
                  const SizedBox(height: 16),
                  const Text(
                    'My Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  productsAsync.when(
                    data: (products) {
                      if (products.isEmpty) {
                        return const EmptyState(
                          title: 'No products yet',
                          subtitle:
                              'Add your first product using the form above.',
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Card(
                            child: ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                '${product.price.toStringAsFixed(0)} ${product.currency} | ${product.category ?? '-'}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showEditDialog(product),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const LoadingView(message: 'Loading products...'),
                    error: (e, _) =>
                        ErrorView(message: 'Failed to load products: $e'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
          loading: () => const LoadingView(message: 'Loading shop portal...'),
          error: (e, _) => ErrorView(message: 'Failed to load portal: $e'),
        ),
      ),
    );
  }

  Widget _buildAddProductForm(String shopId) {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Product name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sizes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kEligibleProductSizes.map((size) {
            final selected = _selectedSizes.contains(size);
            return FilterChip(
              label: Text(size),
              selected: selected,
              onSelected: (enabled) {
                setState(() {
                  if (enabled) {
                    _selectedSizes.add(size);
                  } else {
                    _selectedSizes.remove(size);
                  }
                  if (_selectedSizes.isEmpty) {
                    _selectedSizes.add('M');
                  }
                });
              },
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _submitting ? null : () => _createProduct(shopId),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add Product'),
          ),
        ),
      ],
    );
  }

  Future<void> _createProduct(String shopId) async {
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty || category.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid name, category, and price.')),
      );
      return;
    }
    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one size.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(productsRepositoryProvider).createProduct(
            shopId: shopId,
            name: name,
            price: price,
            category: category,
            sizes: _selectedSizes.toList(growable: false),
            description: description.isEmpty ? null : description,
          );
      _nameController.clear();
      _priceController.clear();
      _categoryController.clear();
      _descriptionController.clear();
      if (mounted) {
        setState(() {
          _selectedSizes
            ..clear()
            ..add('M');
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create product: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showEditDialog(Product product) async {
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl =
        TextEditingController(text: product.price.toStringAsFixed(0));
    final categoryCtrl = TextEditingController(text: product.category ?? '');
    final descCtrl = TextEditingController(text: product.description ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final price = double.tryParse(priceCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty ||
                    categoryCtrl.text.trim().isEmpty ||
                    price == null ||
                    price <= 0) {
                  return;
                }
                await ref.read(productsRepositoryProvider).updateProduct(
                      productId: product.id,
                      name: nameCtrl.text.trim(),
                      price: price,
                      category: categoryCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    categoryCtrl.dispose();
    descCtrl.dispose();
  }
}

