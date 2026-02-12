import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/core/constants/product_sizes.dart';

class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.category,
    this.imageUrl,
    required this.imageUrls,
    required this.colors,
    required this.sizeStock,
    required this.sizeReserved,
    required this.variants,
    required this.isActive,
    required this.hasVariants,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final String? category;
  final String? imageUrl;
  final List<String> imageUrls;
  final List<String> colors;
  final Map<String, int> sizeStock;
  final Map<String, int> sizeReserved;
  final Map<String, ProductVariant> variants;
  final bool isActive;
  final bool hasVariants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get defaultPrice => price;

  List<String> get sizes {
    final keys = <String>{};
    for (final key in <String>{...variants.keys, ...sizeStock.keys, ...sizeReserved.keys}) {
      final normalized = normalizeSizeKey(key);
      if (isEligibleProductSize(normalized)) {
        keys.add(normalized);
      }
    }
    if (keys.isEmpty) {
      return const <String>['M'];
    }
    final values = keys.toList()..sort();
    return values;
  }

  int stockForSize(String size) {
    final key = normalizeSizeKey(size);
    final variant = variants[key];
    if (variant != null) return variant.stock;
    return sizeStock[key] ?? 0;
  }

  int reservedForSize(String size) {
    final key = normalizeSizeKey(size);
    if (sizeReserved.containsKey(key)) return sizeReserved[key] ?? 0;
    final variant = variants[key];
    if (variant != null) return variant.reserved;
    return 0;
  }

  int availableForSize(String size) {
    final available = stockForSize(size) - reservedForSize(size);
    return available < 0 ? 0 : available;
  }

  int get totalStock =>
      sizes.fold<int>(0, (total, size) => total + stockForSize(size));
  int get totalReserved =>
      sizes.fold<int>(0, (total, size) => total + reservedForSize(size));
  int get totalAvailable {
    final value = totalStock - totalReserved;
    return value < 0 ? 0 : value;
  }

  static String normalizeSizeKey(String rawSize) {
    return normalizeProductSize(rawSize, fallback: 'M');
  }

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtTs = data['createdAt'] as Timestamp?;
    final updatedAtTs = data['updatedAt'] as Timestamp?;

    final sizeStock = _parseSizeMap(data['sizeStock']);
    final sizeReserved = _parseSizeMap(data['sizeReserved']);
    final variants = _parseVariants(data['variants']);

    final legacyStock = (data['stock'] as num?)?.toInt();
    final fallbackStock =
        legacyStock != null && legacyStock > 0 ? legacyStock : 10;

    if (variants.isNotEmpty) {
      for (final entry in variants.entries) {
        sizeStock.putIfAbsent(entry.key, () => entry.value.stock);
        sizeReserved.putIfAbsent(entry.key, () => entry.value.reserved);
      }
    }

    if (sizeStock.isEmpty) {
      sizeStock['M'] = fallbackStock;
    }
    if (variants.isEmpty) {
      for (final size in sizeStock.keys) {
        variants[size] = ProductVariant(
          stock: sizeStock[size] ?? 0,
          reserved: sizeReserved[size] ?? 0,
          price: null,
          sku: null,
          barcode: null,
        );
      }
    } else {
      for (final size in variants.keys) {
        variants[size] = variants[size]!.copyWith(
          reserved: sizeReserved[size] ?? variants[size]!.reserved,
        );
      }
    }

    final imageUrls = _parseImageUrls(data['imageUrls'], data['imageUrl']);

    return Product(
      id: doc.id,
      shopId: (data['shopId'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      description: data['description'] as String?,
      price: ((data['defaultPrice'] ?? data['price'] ?? 0) as num).toDouble(),
      currency: (data['currency'] ?? 'UZS') as String,
      category: data['category'] as String?,
      imageUrl:
          imageUrls.isNotEmpty ? imageUrls.first : data['imageUrl'] as String?,
      imageUrls: imageUrls,
      colors: (data['colors'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      sizeStock: sizeStock,
      sizeReserved: sizeReserved,
      variants: variants,
      isActive: (data['isActive'] as bool?) ?? true,
      hasVariants: (data['hasVariants'] as bool?) ?? variants.length > 1,
      createdAt: createdAtTs?.toDate(),
      updatedAt: updatedAtTs?.toDate(),
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.stock,
    required this.reserved,
    required this.price,
    required this.sku,
    required this.barcode,
  });

  final int stock;
  final int reserved;
  final double? price;
  final String? sku;
  final String? barcode;

  int get available {
    final value = stock - reserved;
    return value < 0 ? 0 : value;
  }

  ProductVariant copyWith({
    int? stock,
    int? reserved,
    double? price,
    bool clearPrice = false,
    String? sku,
    bool clearSku = false,
    String? barcode,
    bool clearBarcode = false,
  }) {
    return ProductVariant(
      stock: stock ?? this.stock,
      reserved: reserved ?? this.reserved,
      price: clearPrice ? null : (price ?? this.price),
      sku: clearSku ? null : (sku ?? this.sku),
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'stock': stock,
      'reserved': reserved,
      'price': price,
      'sku': sku,
      'barcode': barcode,
    };
  }
}

Map<String, int> _parseSizeMap(dynamic raw) {
  if (raw is! Map) return <String, int>{};
  final parsed = <String, int>{};
  raw.forEach((key, value) {
    final normalizedKey = Product.normalizeSizeKey(key.toString());
    if (normalizedKey.isEmpty) return;
    final number =
        value is num ? value.toInt() : int.tryParse(value.toString());
    if (number == null || number < 0) return;
    parsed[normalizedKey] = number;
  });
  return parsed;
}

Map<String, ProductVariant> _parseVariants(dynamic raw) {
  if (raw is! Map) return <String, ProductVariant>{};
  final parsed = <String, ProductVariant>{};
  raw.forEach((key, value) {
    if (value is! Map) return;
    final size = Product.normalizeSizeKey(key.toString());
    if (size.isEmpty) return;
    parsed[size] = ProductVariant(
      stock: _toNonNegativeInt(value['stock']),
      reserved: _toNonNegativeInt(value['reserved']),
      price: _toNullableDouble(value['price']),
      sku: _toNullableTrimmedString(value['sku']),
      barcode: _toNullableTrimmedString(value['barcode']),
    );
  });
  return parsed;
}

List<String> _parseImageUrls(dynamic rawImageUrls, dynamic rawImageUrl) {
  final urls = <String>[];
  if (rawImageUrls is List) {
    for (final item in rawImageUrls) {
      final value = item.toString().trim();
      if (value.isNotEmpty) {
        urls.add(value);
      }
    }
  }
  if (urls.isEmpty) {
    final fallback = rawImageUrl?.toString().trim() ?? '';
    if (fallback.isNotEmpty) {
      urls.add(fallback);
    }
  }
  return urls;
}

int _toNonNegativeInt(dynamic value) {
  if (value is num) {
    final intValue = value.toInt();
    return intValue < 0 ? 0 : intValue;
  }
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) return 0;
  return parsed;
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

String? _toNullableTrimmedString(dynamic value) {
  final parsed = value?.toString().trim();
  if (parsed == null || parsed.isEmpty) return null;
  return parsed;
}
