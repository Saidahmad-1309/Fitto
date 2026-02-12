import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/profile_providers.dart';

class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  static const List<String> _genders = ['male', 'female', 'other'];
  static const List<String> _styles = [
    'casual',
    'streetwear',
    'classic',
    'formal',
    'sporty',
  ];
  static const List<String> _budgetOptions = ['low', 'medium', 'high'];
  static const List<String> _colorOptions = [
    'black',
    'white',
    'blue',
    'red',
    'green',
    'beige',
    'brown',
    'gray',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _ProfileSetupBody(
      user: user,
      genders: _genders,
      styles: _styles,
      budgetOptions: _budgetOptions,
      colorOptions: _colorOptions,
    );
  }
}

class _ProfileSetupBody extends ConsumerWidget {
  const _ProfileSetupBody({
    required this.user,
    required this.genders,
    required this.styles,
    required this.budgetOptions,
    required this.colorOptions,
  });

  final User user;
  final List<String> genders;
  final List<String> styles;
  final List<String> budgetOptions;
  final List<String> colorOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(user.uid));
    final controller = ref.read(profileControllerProvider(user.uid).notifier);
    final state = ref.watch(profileControllerProvider(user.uid));

    profileAsync.whenData(controller.initializeFromProfile);

    ref.listen(profileControllerProvider(user.uid), (prev, next) {
      final prevError = prev?.errorMessage;
      final nextError = next.errorMessage;
      if (nextError != null && nextError != prevError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(nextError)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: profileAsync.when(
          data: (_) => AbsorbPointer(
            absorbing: state.isSubmitting,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Tell us your fashion preferences.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: state.gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      genders
                          .map(
                            (gender) => DropdownMenuItem<String>(
                              value: gender,
                              child: Text(gender),
                            ),
                          )
                          .toList(),
                  onChanged: controller.setGender,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: state.ageInput,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.setAgeInput,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Style Preferences *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      styles
                          .map(
                            (style) => FilterChip(
                              label: Text(style),
                              selected: state.stylePreferences.contains(style),
                              onSelected:
                                  (_) => controller.toggleStylePreference(style),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: state.budget,
                  decoration: const InputDecoration(
                    labelText: 'Budget Range *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      budgetOptions
                          .map(
                            (budget) => DropdownMenuItem<String>(
                              value: budget,
                              child: Text(budget),
                            ),
                          )
                          .toList(),
                  onChanged: controller.setBudget,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Favorite Colors *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      colorOptions
                          .map(
                            (color) => FilterChip(
                              label: Text(color),
                              selected: state.favoriteColors.contains(color),
                              onSelected:
                                  (_) => controller.toggleFavoriteColor(color),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed:
                      state.isSubmitting
                          ? null
                          : () async {
                            final success = await controller.submit();
                            if (!context.mounted) return;
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile saved successfully.'),
                                ),
                              );
                            }
                          },
                  child:
                      state.isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Save and Continue'),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load profile: $error'),
                ),
              ),
        ),
      ),
    );
  }
}
