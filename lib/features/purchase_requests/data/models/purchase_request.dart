import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/core/constants/product_sizes.dart';

class PurchaseRequest {
  const PurchaseRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.quantity,
    required this.size,
    required this.reserved,
    required this.reservationQty,
    this.orderId,
    this.shopId,
    this.productId,
    this.expiresAt,
    this.reservedAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String status;
  final String title;
  final String description;
  final DateTime createdAt;
  final int quantity;
  final String size;
  final bool reserved;
  final int reservationQty;
  final String? orderId;
  final String? shopId;
  final String? productId;
  final DateTime? expiresAt;
  final DateTime? reservedAt;
  final DateTime? updatedAt;

  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get canPayNow => isAccepted && !isExpired;

  factory PurchaseRequest.fromMap(String id, Map<String, dynamic> map) {
    return PurchaseRequest(
      id: id,
      userId: (map['userId'] ?? '') as String,
      status: (map['status'] ?? 'pending') as String,
      title:
          (map['title'] ?? map['productName'] ?? 'Purchase request') as String,
      description: (map['description'] ?? '') as String,
      createdAt: _parseDate(map['createdAt']),
      quantity: _parseQuantity(map['quantity']),
      size: _parseSize(map['size']),
      reserved: (map['reserved'] as bool?) ?? false,
      reservationQty: _parseReservationQty(
        map['reservationQty'],
        fallback: map['quantity'],
      ),
      orderId: map['orderId'] as String?,
      shopId: map['shopId'] as String?,
      productId: map['productId'] as String?,
      expiresAt: _parseNullableDate(map['expiresAt']),
      reservedAt: _parseNullableDate(map['reservedAt']),
      updatedAt: _parseNullableDate(map['updatedAt']),
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

int _parseQuantity(dynamic value) {
  if (value is int && value > 0) return value;
  if (value is num && value.toInt() > 0) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null && parsed > 0) return parsed;
  return 1;
}

int _parseReservationQty(dynamic value, {dynamic fallback}) {
  if (value is int && value > 0) return value;
  if (value is num && value.toInt() > 0) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null && parsed > 0) return parsed;
  return _parseQuantity(fallback);
}

String _parseSize(dynamic value) {
  return normalizeProductSize((value ?? '').toString(), fallback: 'M');
}
