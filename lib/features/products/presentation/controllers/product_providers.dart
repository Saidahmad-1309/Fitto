import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/products/data/models/product_model.dart';
import 'package:fitto/features/products/data/repositories/product_repository.dart';

enum ProductSort { none, priceLowToHigh, priceHighToLow }

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(firestore: ref.watch(firestoreProvider));
});

final productSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedProductCategoryProvider = StateProvider<String?>((ref) => null);
final productSortProvider = StateProvider<ProductSort>((ref) => ProductSort.none);

final globalProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  return ref.watch(productRepositoryProvider).watchProducts();
});

final shopProductsProvider = StreamProvider.family<List<ProductModel>, String>((ref, shopId) {
  return ref.watch(productRepositoryProvider).watchProducts(shopId: shopId);
});

final productDetailProvider = StreamProvider.family<ProductModel?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});

final filteredGlobalProductsProvider = Provider<AsyncValue<List<ProductModel>>>((ref) {
  final base = ref.watch(globalProductsProvider);
  final query = ref.watch(productSearchQueryProvider);
  final category = ref.watch(selectedProductCategoryProvider);
  final sort = ref.watch(productSortProvider);
  return base.whenData(
    (products) => _applyFilters(
      products: products,
      query: query,
      category: category,
      sort: sort,
    ),
  );
});

final filteredShopProductsProvider =
    Provider.family<AsyncValue<List<ProductModel>>, String>((ref, shopId) {
      final base = ref.watch(shopProductsProvider(shopId));
      final query = ref.watch(productSearchQueryProvider);
      final category = ref.watch(selectedProductCategoryProvider);
      final sort = ref.watch(productSortProvider);
      return base.whenData(
        (products) => _applyFilters(
          products: products,
          query: query,
          category: category,
          sort: sort,
        ),
      );
    });

List<ProductModel> _applyFilters({
  required List<ProductModel> products,
  required String query,
  required String? category,
  required ProductSort sort,
}) {
  var filtered = products;
  final normalizedQuery = query.trim().toLowerCase();

  if (normalizedQuery.isNotEmpty) {
    filtered = filtered
        .where((item) => item.title.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  if (category != null && category.isNotEmpty) {
    filtered = filtered.where((item) => item.category == category).toList();
  }

  switch (sort) {
    case ProductSort.none:
      break;
    case ProductSort.priceLowToHigh:
      filtered = [...filtered]..sort((a, b) => a.price.compareTo(b.price));
      break;
    case ProductSort.priceHighToLow:
      filtered = [...filtered]..sort((a, b) => b.price.compareTo(a.price));
      break;
  }

  return filtered;
}
