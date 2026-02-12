import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../products/data/models/product_model.dart';
import '../models/shop_model.dart';

class ShopRepository {
  ShopRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<ShopModel>> watchShops() {
    return _firestore
        .collection('shops')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ShopModel.fromDoc).toList());
  }

  Stream<ShopModel?> watchShop(String shopId) {
    return _firestore.collection('shops').doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShopModel.fromDoc(doc);
    });
  }

  Future<void> seedSampleData() async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    final shopA = _firestore.collection('shops').doc('style_hub_tashkent');
    final shopB = _firestore.collection('shops').doc('urban_lane_samarqand');
    final shopC = _firestore.collection('shops').doc('classic_point_bukhara');

    batch.set(shopA, {
      'name': 'Style Hub',
      'address': '12 Amir Temur Ave',
      'city': 'Tashkent',
      'phone': '+998901112233',
      'instagram': '@stylehub.uz',
      'deliveryAvailable': true,
      'openingHours': '10:00 - 22:00',
      'approved': true,
      'isApproved': true,
      'isActive': true,
      'createdAt': now,
    });

    batch.set(shopB, {
      'name': 'Urban Lane',
      'address': '45 Registan Street',
      'city': 'Samarqand',
      'phone': '+998907778899',
      'instagram': '@urbanlane',
      'deliveryAvailable': true,
      'openingHours': '09:00 - 21:00',
      'approved': true,
      'isApproved': true,
      'isActive': true,
      'createdAt': now,
    });

    batch.set(shopC, {
      'name': 'Classic Point',
      'address': '8 Old City Road',
      'city': 'Bukhara',
      'deliveryAvailable': false,
      'openingHours': '11:00 - 20:00',
      'approved': true,
      'isApproved': true,
      'isActive': true,
      'createdAt': now,
    });

    final sampleProducts = <ProductModel>[
      ProductModel(
        productId: 'prd_jacket_1',
        shopId: shopA.id,
        title: 'Black Denim Jacket',
        description: 'Classic fit denim jacket for casual streetwear looks.',
        category: 'jacket',
        price: 420000,
        currency: 'UZS',
        images: const [],
        availableSizes: const ['S', 'M', 'L'],
        availableColors: const ['black'],
        stock: 8,
      ),
      ProductModel(
        productId: 'prd_shoes_1',
        shopId: shopA.id,
        title: 'White Street Sneakers',
        description: 'Comfortable everyday sneakers with minimal design.',
        category: 'shoes',
        price: 550000,
        currency: 'UZS',
        images: const [],
        availableSizes: const ['40', '41', '42', '43'],
        availableColors: const ['white', 'gray'],
        stock: 12,
      ),
      ProductModel(
        productId: 'prd_jeans_1',
        shopId: shopB.id,
        title: 'Slim Blue Jeans',
        description: 'Stretch denim jeans for daily wear.',
        category: 'jeans',
        price: 320000,
        currency: 'UZS',
        images: const [],
        availableSizes: const ['30', '32', '34'],
        availableColors: const ['blue'],
        stock: 15,
      ),
      ProductModel(
        productId: 'prd_tshirt_1',
        shopId: shopB.id,
        title: 'Oversized Tee',
        description: 'Soft cotton oversized t-shirt.',
        category: 't-shirt',
        price: 180000,
        currency: 'UZS',
        images: const [],
        availableSizes: const ['M', 'L', 'XL'],
        availableColors: const ['black', 'white', 'green'],
        stock: 25,
      ),
      ProductModel(
        productId: 'prd_formal_1',
        shopId: shopC.id,
        title: 'Navy Blazer',
        description: 'Formal blazer for smart occasions.',
        category: 'formal',
        price: 780000,
        currency: 'UZS',
        images: const [],
        availableSizes: const ['M', 'L'],
        availableColors: const ['navy'],
        stock: 6,
      ),
    ];

    for (final product in sampleProducts) {
      final normalizedSizes = product.availableSizes
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final fallbackSizes =
          normalizedSizes.isEmpty ? const <String>['M'] : normalizedSizes;
      final baseStock = product.stock ~/ fallbackSizes.length;
      var remainder = product.stock % fallbackSizes.length;
      final sizeStock = <String, int>{};
      final sizeReserved = <String, int>{};
      final variants = <String, Map<String, dynamic>>{};
      for (final size in fallbackSizes) {
        final stockForSize = baseStock + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
        sizeStock[size] = stockForSize;
        sizeReserved[size] = 0;
        variants[size] = <String, dynamic>{
          'stock': stockForSize,
          'reserved': 0,
          'price': null,
          'sku': null,
          'barcode': null,
        };
      }

      batch.set(_firestore.collection('products').doc(product.productId), {
        'shopId': product.shopId,
        'name': product.title,
        'title': product.title,
        'description': product.description,
        'category': product.category,
        'price': product.price,
        'defaultPrice': product.price,
        'currency': product.currency,
        'images': product.images,
        'imageUrls': product.images,
        'colors': product.availableColors,
        'availableSizes': fallbackSizes,
        'availableColors': product.availableColors,
        'variants': variants,
        'hasVariants': fallbackSizes.length > 1,
        'sizeStock': sizeStock,
        'sizeReserved': sizeReserved,
        'stock': product.stock,
        'isActive': true,
        'shopApproved': true,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }
}
