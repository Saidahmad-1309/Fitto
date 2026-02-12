import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/shops/data/models/shop_model.dart';
import 'package:fitto/features/shops/data/repositories/shop_repository.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(firestore: ref.watch(firestoreProvider));
});

final shopListProvider = StreamProvider<List<ShopModel>>((ref) {
  return ref.watch(shopRepositoryProvider).watchShops();
});

final shopDetailProvider = StreamProvider.family<ShopModel?, String>((ref, shopId) {
  return ref.watch(shopRepositoryProvider).watchShop(shopId);
});
