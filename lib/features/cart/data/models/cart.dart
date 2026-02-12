import 'cart_item.dart';

class Cart {
  const Cart({
    required this.userId,
    required this.items,
  });

  final String userId;
  final List<CartItem> items;

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory Cart.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? const []);
    return Cart(
      userId: (map['userId'] ?? '') as String,
      items:
          rawItems
              .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
              .toList(),
    );
  }
}
