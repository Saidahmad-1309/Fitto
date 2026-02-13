import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/cart/data/repositories/cart_repository.dart';
import 'package:fitto/features/cart/presentation/controllers/cart_providers.dart';

import '../../../cart/data/models/cart.dart';
import '../../data/models/order.dart';
import '../../data/repositories/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(firestore: ref.watch(firestoreProvider));
});

final ordersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream<List<OrderModel>>.empty();
  return ref.watch(ordersRepositoryProvider).watchOrders(user.uid);
});

final orderDetailProvider =
    StreamProvider.family<OrderModel?, String>((ref, orderId) {
  return ref.watch(ordersRepositoryProvider).watchOrder(orderId);
});

final ordersControllerProvider = Provider<OrdersController>((ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  final cartRepo = ref.watch(cartRepositoryProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  return OrdersController(
    repository: repo,
    cartRepository: cartRepo,
    userId: user?.uid,
  );
});

class OrdersController {
  OrdersController({
    required OrdersRepository repository,
    required CartRepository cartRepository,
    required String? userId,
  })  : _repository = repository,
        _cartRepository = cartRepository,
        _userId = userId;

  final OrdersRepository _repository;
  final CartRepository _cartRepository;
  final String? _userId;

  Future<bool> checkoutFromCart(Cart? cart) async {
    return checkoutFromCartWithPaymentMethod(
      cart,
      paymentMethod: 'online_payment',
    );
  }

  Future<bool> checkoutFromCartWithPaymentMethod(
    Cart? cart, {
    required String paymentMethod,
  }) async {
    final userId = _userId;
    if (userId == null || cart == null || cart.isEmpty) return false;
    await _repository.createOrderFromCart(
      userId: userId,
      cart: cart,
      deliveryAddress: 'TBD',
      paymentMethod: paymentMethod,
    );
    await _cartRepository.clearCart(userId);
    return true;
  }

  Future<void> updateOrderStatusByShop({
    required String orderId,
    required String shopId,
    required String nextStatus,
  }) {
    return _repository.updateOrderStatusByShop(
      orderId: orderId,
      shopId: shopId,
      nextStatus: nextStatus,
    );
  }
}
