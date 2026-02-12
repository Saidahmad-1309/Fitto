import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fitto/features/products/data/models/product.dart';

class InventoryRepository {
  InventoryRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<Product>> watchShopProducts(String shopId) {
    final normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return Stream.value(const <Product>[]);
    }
    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: normalizedShopId)
        .snapshots()
        .map((snapshot) {
      final products =
          snapshot.docs.map(Product.fromDoc).toList(growable: false);
      return products;
    });
  }

  Stream<Product?> watchProduct(String productId) {
    final normalized = productId.trim();
    if (normalized.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('products')
        .doc(normalized)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Product.fromDoc(doc);
    });
  }

  Future<void> updateProductVariants({
    required String productId,
    required Map<String, ProductVariant> variants,
  }) async {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty) {
      throw ArgumentError('productId cannot be empty');
    }
    final normalizedVariants = _normalizeVariantMap(variants);
    _validateVariantMap(normalizedVariants);

    final sizeStock = <String, int>{};
    final sizeReserved = <String, int>{};
    final variantPayload = <String, Map<String, dynamic>>{};

    for (final entry in normalizedVariants.entries) {
      sizeStock[entry.key] = entry.value.stock;
      sizeReserved[entry.key] = entry.value.reserved;
      variantPayload[entry.key] = entry.value.toMap();
    }

    await _firestore.collection('products').doc(normalizedProductId).set(
      {
        'variants': variantPayload,
        'hasVariants': normalizedVariants.length > 1,
        'sizeStock': sizeStock,
        'sizeReserved': sizeReserved,
        'stock': _sum(sizeStock.values),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateVariantStock({
    required String productId,
    required String variantKey,
    required int newStock,
  }) async {
    final normalizedVariantKey = Product.normalizeSizeKey(variantKey);
    await _firestore.runTransaction((tx) async {
      final docRef = _firestore.collection('products').doc(productId);
      final productSnap = await tx.get(docRef);
      if (!productSnap.exists) {
        throw StateError('Product not found.');
      }
      final product = Product.fromDoc(productSnap);
      final variant = product.variants[normalizedVariantKey];
      if (variant == null) {
        throw StateError('Variant does not exist.');
      }
      if (newStock < variant.reserved) {
        throw StateError(
          'Stock cannot be lower than reserved (${variant.reserved}).',
        );
      }
      final nextVariants = Map<String, ProductVariant>.from(product.variants)
        ..[normalizedVariantKey] = variant.copyWith(stock: newStock);
      tx.set(
        docRef,
        _buildVariantMergePayload(nextVariants),
        SetOptions(merge: true),
      );
    });
  }

  Future<void> addVariant({
    required String productId,
    required String variantKey,
  }) async {
    final normalizedVariantKey = Product.normalizeSizeKey(variantKey);
    await _firestore.runTransaction((tx) async {
      final docRef = _firestore.collection('products').doc(productId);
      final productSnap = await tx.get(docRef);
      if (!productSnap.exists) {
        throw StateError('Product not found.');
      }
      final product = Product.fromDoc(productSnap);
      if (product.variants.containsKey(normalizedVariantKey)) {
        throw StateError('Variant already exists.');
      }
      final nextVariants = Map<String, ProductVariant>.from(product.variants)
        ..[normalizedVariantKey] = const ProductVariant(
          stock: 0,
          reserved: 0,
          price: null,
          sku: null,
          barcode: null,
        );
      tx.set(
        docRef,
        _buildVariantMergePayload(nextVariants),
        SetOptions(merge: true),
      );
    });
  }

  Future<void> removeVariant({
    required String productId,
    required String variantKey,
  }) async {
    final normalizedVariantKey = Product.normalizeSizeKey(variantKey);
    await _firestore.runTransaction((tx) async {
      final docRef = _firestore.collection('products').doc(productId);
      final productSnap = await tx.get(docRef);
      if (!productSnap.exists) {
        throw StateError('Product not found.');
      }
      final product = Product.fromDoc(productSnap);
      final variant = product.variants[normalizedVariantKey];
      if (variant == null) {
        throw StateError('Variant does not exist.');
      }
      if (variant.stock > 0 || variant.reserved > 0) {
        throw StateError(
            'Can only remove empty variants (stock=0,reserved=0).');
      }
      if (product.variants.length == 1) {
        throw StateError('At least one variant is required.');
      }
      final nextVariants = Map<String, ProductVariant>.from(product.variants)
        ..remove(normalizedVariantKey);
      tx.set(
        docRef,
        _buildVariantMergePayload(nextVariants),
        SetOptions(merge: true),
      );
    });
  }

  Map<String, dynamic> _buildVariantMergePayload(
    Map<String, ProductVariant> variants,
  ) {
    final normalizedVariants = _normalizeVariantMap(variants);
    _validateVariantMap(normalizedVariants);

    final variantPayload = <String, Map<String, dynamic>>{};
    final sizeStock = <String, int>{};
    final sizeReserved = <String, int>{};

    for (final entry in normalizedVariants.entries) {
      variantPayload[entry.key] = entry.value.toMap();
      sizeStock[entry.key] = entry.value.stock;
      sizeReserved[entry.key] = entry.value.reserved;
    }

    return <String, dynamic>{
      'variants': variantPayload,
      'hasVariants': normalizedVariants.length > 1,
      'sizeStock': sizeStock,
      'sizeReserved': sizeReserved,
      'stock': _sum(sizeStock.values),
      'shopApproved': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, ProductVariant> _normalizeVariantMap(
    Map<String, ProductVariant> source,
  ) {
    final normalized = <String, ProductVariant>{};
    for (final entry in source.entries) {
      final key = Product.normalizeSizeKey(entry.key);
      if (key.isEmpty) continue;
      normalized[key] = entry.value;
    }
    return normalized;
  }

  void _validateVariantMap(Map<String, ProductVariant> variants) {
    if (variants.isEmpty) {
      throw StateError('At least one variant is required.');
    }
    for (final entry in variants.entries) {
      if (entry.key.trim().isEmpty) {
        throw StateError('Variant size key cannot be empty.');
      }
      final variant = entry.value;
      if (variant.stock < 0) {
        throw StateError('Stock cannot be negative for ${entry.key}.');
      }
      if (variant.reserved < 0) {
        throw StateError('Reserved cannot be negative for ${entry.key}.');
      }
      if (variant.stock < variant.reserved) {
        throw StateError(
          'Stock cannot be lower than reserved for ${entry.key}.',
        );
      }
      if (variant.price != null && variant.price! < 0) {
        throw StateError('Price override cannot be negative for ${entry.key}.');
      }
    }
  }

  int _sum(Iterable<int> values) {
    var total = 0;
    for (final value in values) {
      total += value;
    }
    return total;
  }
}
