import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';

import '../../data/models/product.dart';
import '../../data/repositories/products_repository.dart';

final _productsSessionUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(firestore: ref.watch(firestoreProvider));
});

final productSearchQueryProvider = StateProvider<String>((ref) {
  ref.watch(_productsSessionUidProvider);
  return '';
});
final selectedProductCategoryProvider = StateProvider<String?>((ref) {
  ref.watch(_productsSessionUidProvider);
  return null;
});
final selectedShopFilterProvider = StateProvider<String?>((ref) {
  ref.watch(_productsSessionUidProvider);
  return null;
});
final productSortOptionProvider = StateProvider<ProductSortOption>(
  (ref) {
    ref.watch(_productsSessionUidProvider);
    return ProductSortOption.newest;
  },
);

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const <Product>[]);
  }
  return ref.watch(productsRepositoryProvider).watchActiveProducts();
});

final shopProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, shopId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const <Product>[]);
  }
  return ref.watch(productsRepositoryProvider).watchProductsByShop(shopId);
});

final filteredProductsProvider =
    Provider.family<AsyncValue<List<Product>>, String?>((ref, fixedShopId) {
  final fallbackShopFilter = ref.watch(selectedShopFilterProvider);
  final effectiveShopId = fixedShopId ?? fallbackShopFilter;
  final productsAsync = ref.watch(productsStreamProvider);
  final searchText = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  final selectedCategory = ref.watch(selectedProductCategoryProvider);
  final sort = ref.watch(productSortOptionProvider);

  return productsAsync.whenData((products) {
    var result = products;
    if (effectiveShopId != null && effectiveShopId.isNotEmpty) {
      result =
          result.where((product) => product.shopId == effectiveShopId).toList();
    }
    if (searchText.isNotEmpty) {
      result = result.where((product) {
        final name = product.name.toLowerCase();
        final category = (product.category ?? '').toLowerCase();
        return name.contains(searchText) || category.contains(searchText);
      }).toList();
    }

    if (selectedCategory != null && selectedCategory.isNotEmpty) {
      result = result
          .where((product) => product.category == selectedCategory)
          .toList();
    }

    switch (sort) {
      case ProductSortOption.newest:
        result = [...result]..sort((a, b) {
            final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bTs.compareTo(aTs);
          });
        break;
      case ProductSortOption.priceAsc:
        result = [...result]..sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.priceDesc:
        result = [...result]..sort((a, b) => b.price.compareTo(a.price));
        break;
    }

    return result;
  });
});

final productCategoriesProvider =
    Provider.family<AsyncValue<List<String>>, String?>((
  ref,
  fixedShopId,
) {
  final fallbackShopFilter = ref.watch(selectedShopFilterProvider);
  final effectiveShopId = fixedShopId ?? fallbackShopFilter;
  return ref.watch(productsStreamProvider).whenData((products) {
    var result = products;
    if (effectiveShopId != null && effectiveShopId.isNotEmpty) {
      result =
          result.where((product) => product.shopId == effectiveShopId).toList();
    }
    final categories = result
        .map((item) => (item.category ?? '').trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  });
});
