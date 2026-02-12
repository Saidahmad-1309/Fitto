import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/user_profile_repository.dart';
import 'profile_state.dart';

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController({
    required UserProfileRepository repository,
    required String uid,
  }) : _repository = repository,
       _uid = uid,
       super(const ProfileState());

  final UserProfileRepository _repository;
  final String _uid;
  bool _initialized = false;

  void initializeFromProfile(UserProfile? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    state = state.copyWith(
      gender: profile.gender,
      ageInput: profile.age?.toString() ?? '',
      stylePreferences: List<String>.from(profile.stylePreferences),
      budget: profile.budget,
      favoriteColors: List<String>.from(profile.favoriteColors),
      profilePhotoUrl: profile.profilePhotoUrl,
      clearError: true,
    );
  }

  void setGender(String? value) {
    state = state.copyWith(gender: value, clearError: true);
  }

  void setAgeInput(String value) {
    state = state.copyWith(ageInput: value, clearError: true);
  }

  void setBudget(String? value) {
    state = state.copyWith(budget: value, clearError: true);
  }

  void toggleStylePreference(String style) {
    final updated = List<String>.from(state.stylePreferences);
    if (updated.contains(style)) {
      updated.remove(style);
    } else {
      updated.add(style);
    }
    state = state.copyWith(stylePreferences: updated, clearError: true);
  }

  void toggleFavoriteColor(String color) {
    final updated = List<String>.from(state.favoriteColors);
    if (updated.contains(color)) {
      updated.remove(color);
    } else {
      updated.add(color);
    }
    state = state.copyWith(favoriteColors: updated, clearError: true);
  }

  Future<bool> submit() async {
    final age = state.parsedAge;
    if (!state.isValid || age == null) {
      state = state.copyWith(
        errorMessage: 'Please complete all required fields.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.saveProfile(
        uid: _uid,
        gender: state.gender!,
        age: age,
        stylePreferences: state.stylePreferences,
        budget: state.budget!,
        favoriteColors: state.favoriteColors,
        profilePhotoUrl: state.profilePhotoUrl,
      );
      state = state.copyWith(isSubmitting: false, clearError: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to save profile. Please try again.',
      );
      return false;
    }
  }
}
