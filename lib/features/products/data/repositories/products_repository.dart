import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/core/constants/product_sizes.dart';

import '../models/product.dart';

enum ProductSortOption { newest, priceAsc, priceDesc }

class ProductsRepository {
  ProductsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<Product>> watchActiveProducts() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Product.fromDoc).toList());
  }

  Stream<List<Product>> watchProductsByShop(String shopId) {
    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map(Product.fromDoc).toList();
      items.sort((a, b) {
        final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });
      return items;
    });
  }

  Future<void> createProduct({
    required String shopId,
    required String name,
    required double price,
    required String category,
    required List<String> sizes,
    String? description,
  }) async {
    final normalizedSizes = sizes
        .map((value) => normalizeProductSize(value, fallback: ''))
        .where((value) => isEligibleProductSize(value))
        .toSet()
        .toList(growable: false);
    final finalSizes =
        normalizedSizes.isEmpty ? const <String>['M'] : normalizedSizes;
    final defaultVariants = <String, dynamic>{};
    final sizeStock = <String, int>{};
    final sizeReserved = <String, int>{};
    for (final size in finalSizes) {
      defaultVariants[size] = const <String, dynamic>{
        'stock': 0,
        'reserved': 0,
        'price': null,
        'sku': null,
        'barcode': null,
      };
      sizeStock[size] = 0;
      sizeReserved[size] = 0;
    }
    await _firestore.collection('products').doc().set({
      'shopId': shopId,
      'name': name,
      'description': description,
      'price': price,
      'defaultPrice': price,
      'currency': 'UZS',
      'category': category,
      'imageUrl': '',
      'imageUrls': const <String>[],
      'colors': const [],
      'availableSizes': finalSizes,
      'variants': defaultVariants,
      'hasVariants': finalSizes.length > 1,
      'sizeStock': sizeStock,
      'sizeReserved': sizeReserved,
      'stock': 0,
      'isActive': true,
      'shopApproved': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required double price,
    required String category,
    String? description,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'name': name,
      'description': description,
      'price': price,
      'defaultPrice': price,
      'category': category,
      'shopApproved': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> seedSampleProducts() async {
    final shopsSnapshot = await _firestore
        .collection('shops')
        .where('isActive', isEqualTo: true)
        .limit(3)
        .get();
    if (shopsSnapshot.docs.isEmpty) {
      throw StateError('No active shops found. Seed shops first.');
    }

    final shopIds = shopsSnapshot.docs.map((doc) => doc.id).toList();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    final samples = [
      {
        'id': 'product_black_tee',
        'shopId': shopIds[0],
        'name': 'Black Essential Tee',
        'description': 'Soft cotton tee for everyday wear.',
        'price': 129000.0,
        'currency': 'UZS',
        'category': 't-shirt',
        'imageUrl': '',
        'colors': ['black', 'white'],
        'variants': {
          'S': {
            'stock': 8,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'M': {
            'stock': 12,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'L': {
            'stock': 9,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
        },
        'sizeStock': {'S': 8, 'M': 12, 'L': 9},
        'sizeReserved': {'S': 0, 'M': 0, 'L': 0},
      },
      {
        'id': 'product_denim_jacket',
        'shopId': shopIds[0],
        'name': 'Denim Jacket',
        'description': 'Classic denim jacket with a relaxed fit.',
        'price': 389000.0,
        'currency': 'UZS',
        'category': 'jacket',
        'imageUrl': '',
        'colors': ['blue', 'black'],
        'variants': {
          'M': {
            'stock': 5,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'L': {
            'stock': 6,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'XL': {
            'stock': 4,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
        },
        'sizeStock': {'M': 5, 'L': 6, 'XL': 4},
        'sizeReserved': {'M': 0, 'L': 0, 'XL': 0},
      },
      {
        'id': 'product_slim_jeans',
        'shopId': shopIds.length > 1 ? shopIds[1] : shopIds[0],
        'name': 'Slim Jeans',
        'description': 'Slim-fit jeans with stretch fabric.',
        'price': 259000.0,
        'currency': 'UZS',
        'category': 'jeans',
        'imageUrl': '',
        'colors': ['indigo'],
        'variants': {
          '30': {
            'stock': 7,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          '32': {
            'stock': 7,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          '34': {
            'stock': 5,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
        },
        'sizeStock': {'30': 7, '32': 7, '34': 5},
        'sizeReserved': {'30': 0, '32': 0, '34': 0},
      },
      {
        'id': 'product_runner_shoes',
        'shopId': shopIds.length > 1 ? shopIds[1] : shopIds[0],
        'name': 'Runner Shoes',
        'description': 'Lightweight running shoes for daily comfort.',
        'price': 499000.0,
        'currency': 'UZS',
        'category': 'shoes',
        'imageUrl': '',
        'colors': ['white', 'gray'],
        'variants': {
          '40': {
            'stock': 6,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          '41': {
            'stock': 6,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          '42': {
            'stock': 6,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
        },
        'sizeStock': {'40': 6, '41': 6, '42': 6},
        'sizeReserved': {'40': 0, '41': 0, '42': 0},
      },
      {
        'id': 'product_formal_shirt',
        'shopId': shopIds.length > 2 ? shopIds[2] : shopIds[0],
        'name': 'Formal Shirt',
        'description': 'Crisp formal shirt for office or events.',
        'price': 289000.0,
        'currency': 'UZS',
        'category': 'shirt',
        'imageUrl': '',
        'colors': ['white', 'lightblue'],
        'variants': {
          'S': {
            'stock': 4,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'M': {
            'stock': 8,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'L': {
            'stock': 7,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
        },
        'sizeStock': {'S': 4, 'M': 8, 'L': 7},
        'sizeReserved': {'S': 0, 'M': 0, 'L': 0},
      },
      {
        'id': 'product_classic_blazer',
        'shopId': shopIds.length > 2 ? shopIds[2] : shopIds[0],
        'name': 'Classic Blazer',
        'description': 'Tailored blazer for a polished look.',
        'price': 799000.0,
        'currency': 'UZS',
        'category': 'blazer',
        'imageUrl': '',
        'colors': ['navy', 'black'],
        'variants': {
          'M': {
            'stock': 3,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'L': {
            'stock': 4,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
          'XL': {
            'stock': 3,
            'reserved': 0,
            'price': null,
            'sku': null,
            'barcode': null,
          },
        },
        'sizeStock': {'M': 3, 'L': 4, 'XL': 3},
        'sizeReserved': {'M': 0, 'L': 0, 'XL': 0},
      },
    ];

    for (final item in samples) {
      final doc = _firestore.collection('products').doc(item['id']! as String);
      batch.set(
          doc,
          {
            'shopId': item['shopId'],
            'name': item['name'],
            'description': item['description'],
            'price': item['price'],
            'defaultPrice': item['price'],
            'currency': item['currency'],
            'category': item['category'],
            'imageUrl': item['imageUrl'],
            'imageUrls': const <String>[],
            'colors': item['colors'],
            'variants': item['variants'],
            'hasVariants': true,
            'sizeStock': item['sizeStock'],
            'sizeReserved': item['sizeReserved'],
            'stock': _sumStock(item['sizeStock']),
            'isActive': true,
            'shopApproved': true,
            'createdAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }

  int _sumStock(dynamic rawMap) {
    if (rawMap is! Map) return 0;
    var total = 0;
    for (final value in rawMap.values) {
      if (value is num) {
        total += value.toInt();
      }
    }
    return total;
  }
}
