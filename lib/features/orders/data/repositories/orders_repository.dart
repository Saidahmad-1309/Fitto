import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/core/constants/product_sizes.dart';

import '../../../cart/data/models/cart.dart';
import '../models/order.dart';

class OrdersRepository {
  OrdersRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<OrderModel>> watchOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return OrderModel.fromMap(doc.id, data);
  }

  Future<void> createOrderFromCart({
    required String userId,
    required Cart cart,
    required String deliveryAddress,
  }) async {
    final validItems = cart.items.where((item) {
      return item.shopId.trim().isNotEmpty &&
          item.productId.trim().isNotEmpty &&
          item.qty > 0;
    }).toList(growable: false);

    if (validItems.isEmpty) {
      throw StateError(
        'Checkout failed: cart items are missing shopId/productId or quantity.',
      );
    }

    final shopIds = validItems
        .map((item) => item.shopId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final requestCount = validItems.length;

    final orderRef = _firestore.collection('orders').doc();
    final batch = _firestore.batch();

    batch.set(orderRef, {
      'userId': userId,
      'items': validItems.map((item) => item.toMap()).toList(),
      'subtotal': cart.subtotal,
      'status': 'pending',
      'shopIds': shopIds,
      'statusSummary': {
        'total': requestCount,
        'pending': 0,
        'requested': requestCount,
        'accepted': 0,
        'paid': 0,
        'rejected': 0,
        'canceled': 0,
        'expired': 0,
        'other': 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deliveryAddress': deliveryAddress,
    });

    for (final item in validItems) {
      final normalizedSize = _normalizeSize(item.size);
      final requestRef = _firestore.collection('purchase_requests').doc();
      batch.set(requestRef, {
        'userId': userId,
        'orderId': orderRef.id,
        'shopId': item.shopId.trim(),
        'productId': item.productId.trim(),
        'size': normalizedSize,
        'quantity': item.qty,
        'title': 'Order request',
        'description':
            'Customer placed ${item.qty} item(s). Size: $normalizedSize. Subtotal: ${(item.priceSnapshot * item.qty).toStringAsFixed(0)} UZS',
        'status': 'requested',
        'reserved': false,
        'reservationQty': 0,
        'priceSnapshot': item.priceSnapshot,
        'productName': item.nameSnapshot,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  String _normalizeSize(String value) {
    return normalizeProductSize(value, fallback: 'M');
  }
}
