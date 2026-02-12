import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/repositories/user_profile_repository.dart';
import 'profile_controller.dart';
import 'profile_state.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(firestore: ref.watch(firestoreProvider));
});

final userProfileProvider = StreamProvider.family<UserProfile?, String>((
  ref,
  uid,
) {
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});

final profileControllerProvider =
    StateNotifierProvider.autoDispose
        .family<ProfileController, ProfileState, String>((ref, uid) {
          return ProfileController(
            repository: ref.watch(userProfileRepositoryProvider),
            uid: uid,
          );
        });
