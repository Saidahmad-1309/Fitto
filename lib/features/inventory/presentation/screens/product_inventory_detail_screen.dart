import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/inventory/presentation/controllers/inventory_providers.dart';
import 'package:fitto/features/products/data/models/product.dart';

class ProductInventoryDetailScreen extends ConsumerStatefulWidget {
  const ProductInventoryDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductInventoryDetailScreen> createState() =>
      _ProductInventoryDetailScreenState();
}

class _ProductInventoryDetailScreenState
    extends ConsumerState<ProductInventoryDetailScreen> {
  final Map<String, TextEditingController> _stockControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _stockFocusNodes = <String, FocusNode>{};

  String? _lastHydratedProductRevision;
  bool _isAddingSize = false;
  String? _selectedNewSize;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _stockFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productInventoryProvider(widget.productId));
    final editState =
        ref.watch(inventoryEditControllerProvider(widget.productId));
    final editController =
        ref.read(inventoryEditControllerProvider(widget.productId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Inventory')),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Product not found.'));
          }

          _hydrateEditorIfNeeded(product, editState.hasChanges);

          final variants = editState.variants.values.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          final addableSizes = kAllowedVariantSizes
              .where((size) => !editState.variants.containsKey(size))
              .toList();
          if (addableSizes.isNotEmpty &&
              (_selectedNewSize == null ||
                  !addableSizes.contains(_selectedNewSize))) {
            _selectedNewSize = addableSizes.first;
          }
          if (addableSizes.isEmpty) {
            _selectedNewSize = null;
          }
          _syncStockFieldCaches(variants.map((item) => item.key).toSet());
          final totalStock =
              variants.fold<int>(0, (sum, item) => sum + item.stock);
          final totalReserved =
              variants.fold<int>(0, (sum, item) => sum + item.reserved);
          final totalAvailable = totalStock - totalReserved;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.image_outlined),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Default price: ${product.defaultPrice.toStringAsFixed(0)} ${product.currency}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _summaryBadge(
                                'Total Stock $totalStock', Colors.blue),
                            _summaryBadge(
                                'Reserved $totalReserved', Colors.orange),
                            _summaryBadge(
                              'Available ${totalAvailable < 0 ? 0 : totalAvailable}',
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.info_outline, size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Reserved means held for pending customer payments.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: variants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final invalidStock = variant.stock < variant.reserved;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Size ${variant.key}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await editController
                                          .removeVariant(variant.key);
                                    },
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Reserved: ${variant.reserved}'),
                              const SizedBox(height: 4),
                              Text(
                                'Available: ${variant.available}',
                                style: TextStyle(
                                  color: variant.available > 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => editController
                                        .decrementStock(variant.key),
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      controller: _stockControllerFor(
                                        variant.key,
                                        variant.stock,
                                      ),
                                      focusNode: _stockFocusNodeFor(
                                        variant.key,
                                      ),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Stock',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final parsed =
                                            int.tryParse(value.trim()) ?? 0;
                                        editController.setStock(
                                            variant.key, parsed);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => editController
                                        .incrementStock(variant.key),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                  if (invalidStock)
                                    const Expanded(
                                      child: Text(
                                        'Stock must be >= reserved',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: variant.priceText,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Override price (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  editController.setPriceText(
                                      variant.key, value);
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: variant.sku,
                                decoration: const InputDecoration(
                                  labelText: 'SKU (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  editController.setSku(variant.key, value);
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: variant.barcode,
                                decoration: const InputDecoration(
                                  labelText: 'Barcode (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  editController.setBarcode(variant.key, value);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (editState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      editState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isAddingSize || addableSizes.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _isAddingSize = true;
                              });
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Size'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed:
                          editState.hasChanges ? editController.reset : null,
                      child: const Text('Reset changes'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: editState.isSaving ||
                              !editState.hasChanges ||
                              !editState.isValid
                          ? null
                          : () async {
                              final ok = await editController.save();
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Inventory updated successfully.'),
                                  ),
                                );
                              } else {
                                final latestState = ref.read(
                                  inventoryEditControllerProvider(
                                    widget.productId,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      latestState.errorMessage ??
                                          'Failed to update inventory.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: editState.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
                if (_isAddingSize) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedNewSize,
                          items: addableSizes
                              .map(
                                (size) => DropdownMenuItem<String>(
                                  value: size,
                                  child: Text(size),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedNewSize = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select size',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _submitAddSize(),
                        child: const Text('Add'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isAddingSize = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const LoadingView(message: 'Loading inventory...'),
        error: (error, _) =>
            ErrorView(message: 'Failed to load product: $error'),
      ),
    );
  }

  Future<void> _submitAddSize() async {
    final rawSize = _selectedNewSize?.trim() ?? '';
    if (!mounted) return;
    if (rawSize.isEmpty) return;

    final controller = ref.read(
      inventoryEditControllerProvider(widget.productId).notifier,
    );
    await controller.addVariant(rawSize.trim());
    final latestState =
        ref.read(inventoryEditControllerProvider(widget.productId));
    if (latestState.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(latestState.errorMessage!)),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isAddingSize = false;
    });
  }

  void _hydrateEditorIfNeeded(Product product, bool hasUnsavedChanges) {
    final revision =
        '${product.id}|${product.updatedAt?.millisecondsSinceEpoch ?? 0}';
    if (_lastHydratedProductRevision == revision) return;
    if (_lastHydratedProductRevision != null && hasUnsavedChanges) return;

    _lastHydratedProductRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(inventoryEditControllerProvider(widget.productId).notifier)
          .loadFromProduct(product);
    });
  }

  TextEditingController _stockControllerFor(String key, int stock) {
    final controller = _stockControllers.putIfAbsent(
      key,
      () => TextEditingController(text: stock.toString()),
    );
    if (controller.text != stock.toString()) {
      final focusNode = _stockFocusNodeFor(key);
      if (!focusNode.hasFocus) {
        controller.text = stock.toString();
      }
    }
    return controller;
  }

  FocusNode _stockFocusNodeFor(String key) {
    return _stockFocusNodes.putIfAbsent(key, FocusNode.new);
  }

  void _syncStockFieldCaches(Set<String> keysInUse) {
    final staleControllerKeys = _stockControllers.keys
        .where((key) => !keysInUse.contains(key))
        .toList();
    for (final key in staleControllerKeys) {
      _stockControllers.remove(key)?.dispose();
    }

    final staleFocusKeys =
        _stockFocusNodes.keys.where((key) => !keysInUse.contains(key)).toList();
    for (final key in staleFocusKeys) {
      _stockFocusNodes.remove(key)?.dispose();
    }
  }
}

Widget _summaryBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}
