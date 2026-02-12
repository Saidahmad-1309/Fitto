import 'package:flutter/foundation.dart';

@immutable
class ProfileState {
  const ProfileState({
    this.gender,
    this.ageInput = '',
    this.stylePreferences = const [],
    this.budget,
    this.favoriteColors = const [],
    this.profilePhotoUrl,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String? gender;
  final String ageInput;
  final List<String> stylePreferences;
  final String? budget;
  final List<String> favoriteColors;
  final String? profilePhotoUrl;
  final bool isSubmitting;
  final String? errorMessage;

  int? get parsedAge => int.tryParse(ageInput.trim());

  bool get isValid {
    final age = parsedAge;
    return (gender != null && gender!.isNotEmpty) &&
        age != null &&
        age > 0 &&
        stylePreferences.isNotEmpty &&
        (budget != null && budget!.isNotEmpty) &&
        favoriteColors.isNotEmpty;
  }

  ProfileState copyWith({
    String? gender,
    String? ageInput,
    List<String>? stylePreferences,
    String? budget,
    List<String>? favoriteColors,
    String? profilePhotoUrl,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      gender: gender ?? this.gender,
      ageInput: ageInput ?? this.ageInput,
      stylePreferences: stylePreferences ?? this.stylePreferences,
      budget: budget ?? this.budget,
      favoriteColors: favoriteColors ?? this.favoriteColors,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
