import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  const ProductModel({
    required this.productId,
    required this.shopId,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.currency,
    required this.images,
    required this.availableSizes,
    required this.availableColors,
    required this.stock,
    this.createdAt,
  });

  final String productId;
  final String shopId;
  final String title;
  final String description;
  final String category;
  final num price;
  final String currency;
  final List<String> images;
  final List<String> availableSizes;
  final List<String> availableColors;
  final int stock;
  final DateTime? createdAt;

  factory ProductModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final createdTs = map['createdAt'] as Timestamp?;
    return ProductModel(
      productId: doc.id,
      shopId: (map['shopId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      price: (map['price'] ?? 0) as num,
      currency: (map['currency'] ?? 'UZS') as String,
      images:
          (map['images'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      availableSizes:
          (map['availableSizes'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      availableColors:
          (map['availableColors'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      stock: (map['stock'] ?? 0) as int,
      createdAt: createdTs?.toDate(),
    );
  }
}
