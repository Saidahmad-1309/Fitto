import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
    required FirebaseAnalytics analytics,
  })  : _auth = auth,
        _firestore = firestore,
        _googleSignIn = googleSignIn,
        _analytics = analytics;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final FirebaseAnalytics _analytics;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _safeAnalytics(
      () => _analytics.logEvent(name: 'sign_out'),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
    }
    await cred.user?.getIdToken(true);

    await _upsertUserDoc(cred.user);
    await _safeAnalytics(
      () => _analytics.logSignUp(signUpMethod: 'email'),
    );
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.getIdToken(true);

    await _upsertUserDoc(cred.user);
    await _safeAnalytics(
      () => _analytics.logLogin(loginMethod: 'email'),
    );
    return cred;
  }

  Future<UserCredential> signInWithGoogle() async {
    // Force account picker on each login so switching users is deterministic.
    await _safeGoogleSignOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign_in_canceled',
        message: 'Google sign-in was canceled.',
      );
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    await userCred.user?.getIdToken(true);
    await _upsertUserDoc(userCred.user);
    await _safeAnalytics(
      () => _analytics.logLogin(loginMethod: 'google'),
    );
    return userCred;
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Falls back to signOut below.
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore provider-level cleanup errors.
    }
  }

  Future<void> _upsertUserDoc(User? user) async {
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    final existingData = snap.data();

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['profileCompleted'] = false;
      data['role'] = 'user';
    } else {
      if (existingData == null ||
          !existingData.containsKey('profileCompleted')) {
        data['profileCompleted'] = false;
      }
      final existingRole = existingData?['role'];
      if (existingRole == null ||
          (existingRole is String && existingRole.trim().isEmpty)) {
        data['role'] = 'user';
      }
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> _safeAnalytics(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Do not block auth flow if analytics logging fails.
    }
  }
}
