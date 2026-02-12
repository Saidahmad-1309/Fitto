import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';

import '../../data/models/purchase_request.dart';
import '../../data/repositories/purchase_requests_repository.dart';

final purchaseRequestsRepositoryProvider =
    Provider<PurchaseRequestsRepository>((ref) {
  return PurchaseRequestsRepository(firestore: ref.watch(firestoreProvider));
});

final myPurchaseRequestsProvider =
    StreamProvider.autoDispose<List<PurchaseRequest>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const <PurchaseRequest>[]);
  return ref
      .watch(purchaseRequestsRepositoryProvider)
      .watchUserRequests(user.uid);
});

final purchaseRequestDetailsProvider =
    FutureProvider.family<PurchaseRequest?, String>((ref, requestId) {
  final normalizedId = requestId.trim();
  if (normalizedId.isEmpty) {
    return Future.value(null);
  }
  return ref
      .watch(purchaseRequestsRepositoryProvider)
      .getRequestById(normalizedId);
});

final myRequestsDeepLinkRequestIdProvider =
    StateProvider<String?>((ref) => null);

final shopPurchaseRequestsProvider =
    StreamProvider.autoDispose.family<List<PurchaseRequest>, String>(
        (ref, shopId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const <PurchaseRequest>[]);
  return ref.watch(purchaseRequestsRepositoryProvider).watchShopRequests(shopId);
});

final purchaseRequestActionsProvider = Provider<PurchaseRequestActions>((ref) {
  final actorUid = ref.watch(authStateProvider).valueOrNull?.uid;
  return PurchaseRequestActions(
    repository: ref.watch(purchaseRequestsRepositoryProvider),
    actorUid: actorUid,
  );
});

class PurchaseRequestActions {
  PurchaseRequestActions({
    required PurchaseRequestsRepository repository,
    required String? actorUid,
  })  : _repository = repository,
        _actorUid = actorUid;

  final PurchaseRequestsRepository _repository;
  final String? _actorUid;

  Future<void> accept(String requestId) {
    return _repository.acceptRequestByShop(
      requestId: requestId,
      actorUid: _requiredActorUid(),
    );
  }

  Future<void> reject(String requestId, {String? reason}) {
    return _repository.rejectRequestByShop(
      requestId: requestId,
      actorUid: _requiredActorUid(),
      rejectionReason: reason,
    );
  }

  Future<PurchaseRequestMutationResult> pay(String requestId) {
    return _repository.payRequestByUser(
      requestId: requestId,
      actorUid: _requiredActorUid(),
    );
  }

  Future<PurchaseRequestMutationResult> expire(String requestId) {
    return _repository.expireRequest(requestId: requestId);
  }

  String _requiredActorUid() {
    final uid = _actorUid?.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError('Authenticated user is required.');
    }
    return uid;
  }
}
