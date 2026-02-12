import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/constants/product_sizes.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/inventory/data/repositories/inventory_repository.dart';
import 'package:fitto/features/products/data/models/product.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(firestore: ref.watch(firestoreProvider));
});

final shopInventoryProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, shopId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const <Product>[]);
  }
  return ref.watch(inventoryRepositoryProvider).watchShopProducts(shopId);
});

final productInventoryProvider = StreamProvider.family<Product?, String>((
  ref,
  productId,
) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(inventoryRepositoryProvider).watchProduct(productId);
});

const List<String> kAllowedVariantSizes = kEligibleProductSizes;

class VariantDraft {
  const VariantDraft({
    required this.key,
    required this.stock,
    required this.reserved,
    required this.priceText,
    required this.sku,
    required this.barcode,
  });

  final String key;
  final int stock;
  final int reserved;
  final String priceText;
  final String sku;
  final String barcode;

  int get available {
    final value = stock - reserved;
    return value < 0 ? 0 : value;
  }

  ProductVariant toProductVariant() {
    final priceRaw = priceText.trim();
    final price = priceRaw.isEmpty ? null : double.tryParse(priceRaw);
    return ProductVariant(
      stock: stock,
      reserved: reserved,
      price: price,
      sku: sku.trim().isEmpty ? null : sku.trim(),
      barcode: barcode.trim().isEmpty ? null : barcode.trim(),
    );
  }

  VariantDraft copyWith({
    String? key,
    int? stock,
    int? reserved,
    String? priceText,
    String? sku,
    String? barcode,
  }) {
    return VariantDraft(
      key: key ?? this.key,
      stock: stock ?? this.stock,
      reserved: reserved ?? this.reserved,
      priceText: priceText ?? this.priceText,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
    );
  }
}

class InventoryEditState {
  const InventoryEditState({
    this.isSaving = false,
    this.errorMessage,
    this.variants = const <String, VariantDraft>{},
    this.loaded = false,
    this.initialVariants = const <String, VariantDraft>{},
  });

  final bool isSaving;
  final String? errorMessage;
  final Map<String, VariantDraft> variants;
  final Map<String, VariantDraft> initialVariants;
  final bool loaded;

  bool get hasChanges => !_mapsEqual(variants, initialVariants);

  bool get isValid {
    for (final variant in variants.values) {
      if (variant.stock < 0) return false;
      if (variant.reserved < 0) return false;
      if (variant.stock < variant.reserved) return false;
      final priceRaw = variant.priceText.trim();
      if (priceRaw.isNotEmpty) {
        final parsed = double.tryParse(priceRaw);
        if (parsed == null || parsed < 0) {
          return false;
        }
      }
    }
    return variants.isNotEmpty;
  }

  InventoryEditState copyWith({
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    Map<String, VariantDraft>? variants,
    Map<String, VariantDraft>? initialVariants,
    bool? loaded,
  }) {
    return InventoryEditState(
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      variants: variants ?? this.variants,
      initialVariants: initialVariants ?? this.initialVariants,
      loaded: loaded ?? this.loaded,
    );
  }
}

class InventoryEditController extends StateNotifier<InventoryEditState> {
  InventoryEditController({
    required InventoryRepository repository,
    required String productId,
  })  : _repository = repository,
        _productId = productId,
        super(const InventoryEditState());

  final InventoryRepository _repository;
  final String _productId;

  void loadFromProduct(Product product) {
    if (state.loaded && state.hasChanges) {
      // Do not overwrite local unsaved edits.
      return;
    }
    final draft = _productToDraft(product);
    if (state.loaded && _mapsEqual(state.initialVariants, draft)) {
      return;
    }
    state = state.copyWith(
      variants: draft,
      initialVariants: draft,
      loaded: true,
      clearError: true,
    );
  }

  void incrementStock(String key) {
    final variant = state.variants[key];
    if (variant == null) return;
    _setVariant(variant.copyWith(stock: variant.stock + 1));
  }

  void decrementStock(String key) {
    final variant = state.variants[key];
    if (variant == null) return;
    if (variant.stock <= variant.reserved) return;
    _setVariant(variant.copyWith(stock: variant.stock - 1));
  }

  void setStock(String key, int stock) {
    final variant = state.variants[key];
    if (variant == null) return;
    _setVariant(variant.copyWith(stock: stock));
  }

  void setPriceText(String key, String value) {
    final variant = state.variants[key];
    if (variant == null) return;
    _setVariant(variant.copyWith(priceText: value));
  }

  void setSku(String key, String value) {
    final variant = state.variants[key];
    if (variant == null) return;
    _setVariant(variant.copyWith(sku: value));
  }

  void setBarcode(String key, String value) {
    final variant = state.variants[key];
    if (variant == null) return;
    _setVariant(variant.copyWith(barcode: value));
  }

  void reset() {
    state = state.copyWith(
      variants: Map<String, VariantDraft>.from(state.initialVariants),
      clearError: true,
    );
  }

  Future<void> addVariant(String key) async {
    final normalizedKey = Product.normalizeSizeKey(key);
    if (normalizedKey.isEmpty) return;
    if (!kAllowedVariantSizes.contains(normalizedKey)) {
      state = state.copyWith(
        errorMessage: 'Invalid size. Use only standard sizes.',
      );
      return;
    }
    if (state.variants.containsKey(normalizedKey)) {
      state = state.copyWith(errorMessage: 'Variant already exists.');
      return;
    }
    final next = Map<String, VariantDraft>.from(state.variants);
    next[normalizedKey] = VariantDraft(
      key: normalizedKey,
      stock: 0,
      reserved: 0,
      priceText: '',
      sku: '',
      barcode: '',
    );
    state = state.copyWith(variants: next, clearError: true);
  }

  Future<void> removeVariant(String key) async {
    final variant = state.variants[key];
    if (variant == null) return;
    if (variant.stock > 0 || variant.reserved > 0) {
      state = state.copyWith(
        errorMessage: 'Only empty variants can be removed.',
      );
      return;
    }
    if (state.variants.length <= 1) {
      state = state.copyWith(
        errorMessage: 'At least one variant is required.',
      );
      return;
    }
    final next = Map<String, VariantDraft>.from(state.variants)..remove(key);
    state = state.copyWith(variants: next, clearError: true);
  }

  Future<bool> save() async {
    if (!state.isValid) {
      state = state.copyWith(
        errorMessage: 'Fix validation errors before saving.',
      );
      return false;
    }
    if (!state.hasChanges) return true;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = <String, ProductVariant>{};
      for (final entry in state.variants.entries) {
        payload[entry.key] = entry.value.toProductVariant();
      }
      await _repository.updateProductVariants(
        productId: _productId,
        variants: payload,
      );
      state = state.copyWith(
        isSaving: false,
        initialVariants: Map<String, VariantDraft>.from(state.variants),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void _setVariant(VariantDraft variant) {
    final next = Map<String, VariantDraft>.from(state.variants)
      ..[variant.key] = variant;
    state = state.copyWith(variants: next, clearError: true);
  }

  Map<String, VariantDraft> _productToDraft(Product product) {
    final draft = <String, VariantDraft>{};
    for (final size in product.sizes) {
      final variant = product.variants[size] ??
          ProductVariant(
            stock: product.stockForSize(size),
            reserved: product.reservedForSize(size),
            price: null,
            sku: null,
            barcode: null,
          );
      draft[size] = VariantDraft(
        key: size,
        stock: variant.stock,
        reserved: product.reservedForSize(size),
        priceText: variant.price?.toStringAsFixed(0) ?? '',
        sku: variant.sku ?? '',
        barcode: variant.barcode ?? '',
      );
    }
    return draft;
  }
}

final inventoryEditControllerProvider = StateNotifierProvider.autoDispose
    .family<InventoryEditController, InventoryEditState, String>(
        (ref, productId) {
  return InventoryEditController(
    repository: ref.watch(inventoryRepositoryProvider),
    productId: productId,
  );
});

bool _mapsEqual(
  Map<String, VariantDraft> a,
  Map<String, VariantDraft> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null) return false;
    if (entry.value.stock != other.stock) return false;
    if (entry.value.reserved != other.reserved) return false;
    if (entry.value.priceText.trim() != other.priceText.trim()) return false;
    if (entry.value.sku.trim() != other.sku.trim()) return false;
    if (entry.value.barcode.trim() != other.barcode.trim()) return false;
  }
  return true;
}
