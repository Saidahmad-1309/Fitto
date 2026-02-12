import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';

import '../controllers/shop_onboarding_providers.dart';

class ShopApplicationScreen extends ConsumerWidget {
  const ShopApplicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final latestAppAsync = ref.watch(latestOwnerApplicationProvider(user.uid));
    final shopLinkAsync = ref.watch(shopUserLinkProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Register Your Shop')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: shopLinkAsync.when(
          data: (link) {
            if (link != null && link.shopId.isNotEmpty) {
              return const EmptyState(
                title: 'Your shop is approved',
                subtitle: 'Open My Shop Portal from Home to manage products.',
              );
            }

            return latestAppAsync.when(
              data: (app) {
                if (app != null && app.status == 'pending') {
                  return const EmptyState(
                    title: 'Application pending',
                    subtitle: 'We are reviewing your submission.',
                  );
                }
                if (app != null && app.status == 'rejected') {
                  return _RejectedView(
                    reason: app.rejectionReason,
                    ownerUid: user.uid,
                  );
                }
                return _ShopApplicationForm(ownerUid: user.uid);
              },
              loading: () =>
                  const LoadingView(message: 'Loading application...'),
              error: (e, _) =>
                  ErrorView(message: 'Failed to load application: $e'),
            );
          },
          loading: () => const LoadingView(message: 'Loading shop status...'),
          error: (e, _) => ErrorView(message: 'Failed to load shop status: $e'),
        ),
      ),
    );
  }
}

class _ShopApplicationForm extends ConsumerWidget {
  const _ShopApplicationForm({required this.ownerUid});

  final String ownerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(shopApplicationFormProvider(ownerUid));
    final controller = ref.read(shopApplicationFormProvider(ownerUid).notifier);

    ref.listen(shopApplicationFormProvider(ownerUid), (prev, next) {
      final prevError = prev?.errorMessage;
      final nextError = next.errorMessage;
      if (nextError != null && nextError != prevError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nextError)),
        );
      }
    });

    return ListView(
      children: [
        const Text(
          'Submit your shop for approval',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Shop name',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.setShopName,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.setCity,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 5,
          onChanged: controller.setDescription,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Contact phone (optional)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          onChanged: controller.setContactPhone,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: formState.isSubmitting
              ? null
              : () async {
                  final success = await controller.submit();
                  if (!context.mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application submitted.')),
                    );
                  }
                },
          child: formState.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _RejectedView extends ConsumerWidget {
  const _RejectedView({required this.reason, required this.ownerUid});

  final String? reason;
  final String ownerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const Text(
          'Application rejected',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if ((reason ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Reason: $reason'),
        ],
        const SizedBox(height: 16),
        const Text('You can submit a new application.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            ref.invalidate(shopApplicationFormProvider(ownerUid));
          },
          child: const Text('Submit new application'),
        ),
        const SizedBox(height: 16),
        _ShopApplicationForm(ownerUid: ownerUid),
      ],
    );
  }
}
