import '../../../cart/data/models/cart_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  final String id;
  final String userId;
  final List<CartItem> items;
  final double subtotal;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String deliveryAddress;
  final String paymentMethod;
  final String paymentStatus;

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? const []);
    return OrderModel(
      id: id,
      userId: (map['userId'] ?? '') as String,
      items: rawItems
          .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
      status: (map['status'] ?? 'pending') as String,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseNullableDate(map['updatedAt']),
      deliveryAddress: (map['deliveryAddress'] ?? '') as String,
      paymentMethod: (map['paymentMethod'] ?? 'cash_on_delivery') as String,
      paymentStatus: (map['paymentStatus'] ?? 'unpaid') as String,
    );
  }
}

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}
