import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/constants/product_sizes.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';

import '../../data/models/cart.dart';
import '../../data/models/cart_item.dart';
import '../../data/repositories/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(firestore: ref.watch(firestoreProvider));
});

final cartStreamProvider = StreamProvider<Cart?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream<Cart?>.empty();
  return ref.watch(cartRepositoryProvider).watchCart(user.uid);
});

final cartControllerProvider = Provider<CartController>((ref) {
  final repo = ref.watch(cartRepositoryProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  return CartController(repository: repo, userId: user?.uid);
});

class CartController {
  CartController({required CartRepository repository, required String? userId})
      : _repository = repository,
        _userId = userId;

  final CartRepository _repository;
  final String? _userId;

  Future<void> addToCart({
    required String productId,
    required String nameSnapshot,
    required double priceSnapshot,
    required String shopId,
    required String size,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final item = CartItem(
      productId: productId,
      nameSnapshot: nameSnapshot,
      priceSnapshot: priceSnapshot,
      qty: 1,
      shopId: shopId,
      size: _normalizeSize(size),
      addedAt: DateTime.now(),
    );
    await _repository.addOrIncrementItem(userId: userId, item: item);
  }

  Future<void> updateQty({
    required String productId,
    required String size,
    required int qty,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.updateQuantity(
      userId: userId,
      productId: productId,
      size: _normalizeSize(size),
      qty: qty,
    );
  }

  Future<void> removeItem({
    required String productId,
    required String size,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.removeItem(
      userId: userId,
      productId: productId,
      size: _normalizeSize(size),
    );
  }

  Future<void> clearCart() async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.clearCart(userId);
  }

  String _normalizeSize(String value) {
    return normalizeProductSize(value, fallback: 'M');
  }
}
