import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';

import '../../data/models/shop.dart';
import '../../data/repositories/shops_repository.dart';

final _shopsSessionUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

final shopsRepositoryProvider = Provider<ShopsRepository>((ref) {
  return ShopsRepository(firestore: ref.watch(firestoreProvider));
});

final shopsSearchQueryProvider = StateProvider<String>((ref) {
  ref.watch(_shopsSessionUidProvider);
  return '';
});

final shopsStreamProvider = StreamProvider<List<Shop>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const <Shop>[]);
  }
  return ref.watch(shopsRepositoryProvider).watchActiveShops();
});

final filteredShopsProvider = Provider<AsyncValue<List<Shop>>>((ref) {
  final shopsAsync = ref.watch(shopsStreamProvider);
  final query = ref.watch(shopsSearchQueryProvider).trim().toLowerCase();

  return shopsAsync.whenData((shops) {
    var result = shops;
    result = [...result]..sort((a, b) {
        final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });
    if (query.isEmpty) return result;
    return result.where((shop) {
      final name = shop.name.toLowerCase();
      final city = (shop.city ?? '').toLowerCase();
      return name.contains(query) || city.contains(query);
    }).toList();
  });
});

final shopsByIdProvider = Provider<AsyncValue<Map<String, Shop>>>((ref) {
  return ref.watch(shopsStreamProvider).whenData((shops) {
    return {for (final shop in shops) shop.id: shop};
  });
});
