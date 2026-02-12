import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/core/constants/product_sizes.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';

class CartRepository {
  CartRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<Cart?> watchCart(String userId) {
    return _firestore.collection('carts').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return Cart.fromMap(data);
    });
  }

  Future<void> addOrIncrementItem({
    required String userId,
    required CartItem item,
  }) async {
    final ref = _firestore.collection('carts').doc(userId);
    final snap = await ref.get();
    final items = _readItems(snap.data());

    final index =
        items.indexWhere((element) => element.lineKey == item.lineKey);
    if (index >= 0) {
      final current = items[index];
      items[index] = CartItem(
        productId: current.productId,
        nameSnapshot: current.nameSnapshot,
        priceSnapshot: current.priceSnapshot,
        qty: current.qty + item.qty,
        shopId: current.shopId,
        size: current.size,
        addedAt: current.addedAt,
      );
    } else {
      items.add(item);
    }

    await ref.set({
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateQuantity({
    required String userId,
    required String productId,
    required String size,
    required int qty,
  }) async {
    final ref = _firestore.collection('carts').doc(userId);
    final snap = await ref.get();
    final items = _readItems(snap.data());

    final normalizedSize = _normalizeSize(size);
    final index = items.indexWhere(
      (element) =>
          element.productId == productId && element.size == normalizedSize,
    );
    if (index == -1) return;

    if (qty <= 0) {
      items.removeAt(index);
    } else {
      final current = items[index];
      items[index] = CartItem(
        productId: current.productId,
        nameSnapshot: current.nameSnapshot,
        priceSnapshot: current.priceSnapshot,
        qty: qty,
        shopId: current.shopId,
        size: current.size,
        addedAt: current.addedAt,
      );
    }

    await ref.set({
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeItem({
    required String userId,
    required String productId,
    required String size,
  }) async {
    await updateQuantity(
      userId: userId,
      productId: productId,
      size: size,
      qty: 0,
    );
  }

  Future<void> clearCart(String userId) async {
    await _firestore.collection('carts').doc(userId).set({
      'userId': userId,
      'items': [],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<CartItem> _readItems(Map<String, dynamic>? data) {
    final rawItems = (data?['items'] as List<dynamic>? ?? const []);
    return rawItems
        .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  String _normalizeSize(String value) {
    return normalizeProductSize(value, fallback: 'M');
  }
}
