import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/repositories/auth_repository.dart';

class CurrentUserDoc {
  const CurrentUserDoc({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.profileCompleted,
  });

  factory CurrentUserDoc.fromMap({
    required String uid,
    required Map<String, dynamic>? data,
  }) {
    final map = data ?? const <String, dynamic>{};
    return CurrentUserDoc(
      uid: uid,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      role: (map['role'] as String?) ?? 'user',
      profileCompleted: (map['profileCompleted'] as bool?) ?? false,
    );
  }

  final String uid;
  final String? email;
  final String? displayName;
  final String role;
  final bool profileCompleted;
}

// Core SDK instances
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn();
});

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    analytics: ref.watch(firebaseAnalyticsProvider),
  );
});

// Auth stream (used by AuthGate)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).idTokenChanges();
});

final userDocByUidProvider =
    StreamProvider.family<CurrentUserDoc?, String>((ref, uid) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return CurrentUserDoc.fromMap(uid: uid, data: doc.data());
  });
});

final currentUserDocProvider = StreamProvider<CurrentUserDoc?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return CurrentUserDoc.fromMap(uid: user.uid, data: doc.data());
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(currentUserDocProvider).valueOrNull?.role ?? 'user';
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == 'admin';
});
