import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';

import '../../data/models/shop_application.dart';
import '../../data/repositories/shop_onboarding_repository.dart';

final shopOnboardingRepositoryProvider = Provider<ShopOnboardingRepository>((ref) {
  return ShopOnboardingRepository(firestore: ref.watch(firestoreProvider));
});

final ownerApplicationsProvider =
    StreamProvider.autoDispose.family<List<ShopApplication>, String>((ref, ownerUid) {
      final authUser = ref.watch(authStateProvider).valueOrNull;
      if (authUser == null) {
        return Stream.value(const <ShopApplication>[]);
      }
      return ref.watch(shopOnboardingRepositoryProvider).watchApplicationsByOwner(ownerUid);
    });

final pendingApplicationsProvider = StreamProvider.autoDispose<List<ShopApplication>>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) {
    return Stream.value(const <ShopApplication>[]);
  }
  return ref.watch(shopOnboardingRepositoryProvider).watchPendingApplications();
});

final shopUserLinkProvider =
    StreamProvider.autoDispose.family<ShopUserLink?, String>((ref, userId) {
      final authUser = ref.watch(authStateProvider).valueOrNull;
      if (authUser == null) {
        return Stream.value(null);
      }
      return ref.watch(shopOnboardingRepositoryProvider).watchShopUserLink(userId);
    });

final latestOwnerApplicationProvider =
    Provider.family<AsyncValue<ShopApplication?>, String>((ref, ownerUid) {
      final appsAsync = ref.watch(ownerApplicationsProvider(ownerUid));
      return appsAsync.whenData((apps) {
        if (apps.isEmpty) return null;
        final sorted = [...apps]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return sorted.last;
      });
    });

class ShopApplicationFormState {
  const ShopApplicationFormState({
    this.shopName = '',
    this.city = '',
    this.description = '',
    this.contactPhone = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String shopName;
  final String city;
  final String description;
  final String contactPhone;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isValid =>
      shopName.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      description.trim().isNotEmpty;

  ShopApplicationFormState copyWith({
    String? shopName,
    String? city,
    String? description,
    String? contactPhone,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShopApplicationFormState(
      shopName: shopName ?? this.shopName,
      city: city ?? this.city,
      description: description ?? this.description,
      contactPhone: contactPhone ?? this.contactPhone,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ShopApplicationFormController extends StateNotifier<ShopApplicationFormState> {
  ShopApplicationFormController({
    required ShopOnboardingRepository repository,
    required String ownerUid,
  }) : _repository = repository,
       _ownerUid = ownerUid,
       super(const ShopApplicationFormState());

  final ShopOnboardingRepository _repository;
  final String _ownerUid;

  void setShopName(String value) {
    state = state.copyWith(shopName: value, clearError: true);
  }

  void setCity(String value) {
    state = state.copyWith(city: value, clearError: true);
  }

  void setDescription(String value) {
    state = state.copyWith(description: value, clearError: true);
  }

  void setContactPhone(String value) {
    state = state.copyWith(contactPhone: value, clearError: true);
  }

  Future<bool> submit() async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Please complete all fields.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.submitApplication(
        ownerUid: _ownerUid,
        shopName: state.shopName.trim(),
        city: state.city.trim(),
        description: state.description.trim(),
        contactPhone: state.contactPhone.trim().isEmpty ? null : state.contactPhone.trim(),
      );
      state = const ShopApplicationFormState();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to submit application: $e',
      );
      return false;
    }
  }
}

final shopApplicationFormProvider = StateNotifierProvider.autoDispose
    .family<ShopApplicationFormController, ShopApplicationFormState, String>(
  (ref, ownerUid) {
    return ShopApplicationFormController(
      repository: ref.watch(shopOnboardingRepositoryProvider),
      ownerUid: ownerUid,
    );
  },
);
