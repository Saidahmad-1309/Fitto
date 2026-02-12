import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/auth/presentation/screens/login_screen.dart';
import 'package:fitto/main_shell.dart';
import 'package:fitto/features/profile/presentation/controllers/profile_providers.dart';
import 'package:fitto/features/profile/presentation/screens/profile_setup_screen.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          if (ref.read(appReadyProvider)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ref.read(appReadyProvider.notifier).state = false;
            });
          }
          return const LoginScreen();
        }
        final profileState = ref.watch(userProfileProvider(user.uid));
        return profileState.when(
          data: (profile) {
            final isProfileComplete = profile?.isComplete ?? false;
            if (!isProfileComplete) {
              if (ref.read(appReadyProvider)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  ref.read(appReadyProvider.notifier).state = false;
                });
              }
              return const ProfileSetupScreen();
            }
            return const MainShell();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) {
            if (_isPermissionDenied(e)) {
              _retryProfileLoad(ref, user.uid);
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Profile error: $e'),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Auth error: $e'),
          ),
        ),
      ),
    );
  }

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('permission-denied');
  }

  void _retryProfileLoad(WidgetRef ref, String uid) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      ref.invalidate(userProfileProvider(uid));
    });
  }
}
