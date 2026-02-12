import 'package:fitto/core/constants/product_sizes.dart';

class CartItem {
  const CartItem({
    required this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.shopId,
    required this.size,
    required this.addedAt,
  });

  final String productId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int qty;
  final String shopId;
  final String size;
  final DateTime addedAt;

  double get lineTotal => priceSnapshot * qty;
  String get lineKey => '$productId::$size';

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'nameSnapshot': nameSnapshot,
      'priceSnapshot': priceSnapshot,
      'qty': qty,
      'shopId': shopId,
      'size': size,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final rawSize = (map['size'] ?? '').toString().trim().toUpperCase();
    return CartItem(
      productId: (map['productId'] ?? '') as String,
      nameSnapshot: (map['nameSnapshot'] ?? '') as String,
      priceSnapshot: ((map['priceSnapshot'] ?? 0) as num).toDouble(),
      qty: (map['qty'] ?? 0) as int,
      shopId: (map['shopId'] ?? '') as String,
      size: normalizeProductSize(rawSize, fallback: 'M'),
      addedAt: DateTime.tryParse((map['addedAt'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
