import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    this.gender,
    this.age,
    required this.stylePreferences,
    this.budget,
    required this.favoriteColors,
    this.profilePhotoUrl,
    required this.profileCompleted,
  });

  final String uid;
  final String? gender;
  final int? age;
  final List<String> stylePreferences;
  final String? budget;
  final List<String> favoriteColors;
  final String? profilePhotoUrl;
  final bool profileCompleted;

  bool get hasRequiredFields {
    return (gender != null && gender!.isNotEmpty) &&
        (age != null && age! > 0) &&
        stylePreferences.isNotEmpty &&
        (budget != null && budget!.isNotEmpty) &&
        favoriteColors.isNotEmpty;
  }

  bool get isComplete => profileCompleted && hasRequiredFields;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: (map['uid'] ?? '') as String,
      gender: map['gender'] as String?,
      age: map['age'] as int?,
      stylePreferences:
          (map['stylePreferences'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      budget: map['budget'] as String?,
      favoriteColors:
          (map['favoriteColors'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      profileCompleted: (map['profileCompleted'] as bool?) ?? false,
    );
  }
}

class UserProfileRepository {
  UserProfileRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return UserProfile.fromMap(data);
    });
  }

  Future<void> saveProfile({
    required String uid,
    required String gender,
    required int age,
    required List<String> stylePreferences,
    required String budget,
    required List<String> favoriteColors,
    String? profilePhotoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'gender': gender,
      'age': age,
      'stylePreferences': stylePreferences,
      'budget': budget,
      'favoriteColors': favoriteColors,
      'profilePhotoUrl': profilePhotoUrl,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
