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
    required this.statusSummary,
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
  final Map<String, int> statusSummary;

  String get resolvedStatus {
    final normalized = status.trim().toLowerCase();
    if (normalized.isNotEmpty && normalized != 'pending') {
      return normalized;
    }
    return _deriveOrderStatusFromSummary(statusSummary);
  }

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
      paymentMethod: _normalizePaymentMethod(map['paymentMethod']),
      paymentStatus: (map['paymentStatus'] ?? 'unpaid') as String,
      statusSummary: _readStatusSummary(map['statusSummary']),
    );
  }
}

String _deriveOrderStatusFromSummary(Map<String, int> summary) {
  final total = summary['total'] ?? 0;
  final pending = summary['pending'] ?? 0;
  final requested = summary['requested'] ?? 0;
  final accepted = summary['accepted'] ?? 0;
  final paid = summary['paid'] ?? 0;
  final rejected = summary['rejected'] ?? 0;
  final canceled = summary['canceled'] ?? 0;
  final expired = summary['expired'] ?? 0;

  if (rejected + canceled + expired > 0) return 'rejected';
  if (total > 0 && paid == total) return 'paid';
  if ((accepted + paid) > 0 && (pending + requested) > 0) return 'processing';
  if (total > 0 && (accepted + paid) == total) return 'accepted';
  return 'pending';
}

Map<String, int> _readStatusSummary(dynamic value) {
  if (value is! Map) return const <String, int>{};
  final result = <String, int>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final raw = entry.value;
    if (raw is int && raw >= 0) {
      result[key] = raw;
    } else if (raw is num && raw.toInt() >= 0) {
      result[key] = raw.toInt();
    }
  }
  return result;
}

String _normalizePaymentMethod(dynamic value) {
  final normalized = (value ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'store_pickup':
      return 'store_pickup';
    case 'online_payment':
      return 'online_payment';
    case 'cash_on_delivery':
    case 'card_on_delivery':
      return 'online_payment';
    default:
      return 'online_payment';
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
