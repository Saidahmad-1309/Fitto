import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/shop_onboarding/presentation/controllers/shop_onboarding_providers.dart';

import 'admin_application_detail_screen.dart';

class AdminApplicationsScreen extends ConsumerWidget {
  const AdminApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access only')),
      );
    }
    final pendingAsync = ref.watch(pendingApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Applications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: pendingAsync.when(
          data: (apps) {
            if (apps.isEmpty) {
              return const EmptyState(
                title: 'No pending applications',
                subtitle: 'New submissions will appear here.',
              );
            }
            final sorted = [...apps]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return ListView.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final app = sorted[index];
                return Card(
                  child: ListTile(
                    title: Text(app.shopName),
                    subtitle: Text(app.city),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => AdminApplicationDetailScreen(application: app),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
          loading: () => const LoadingView(message: 'Loading applications...'),
          error: (e, _) => ErrorView(message: 'Failed to load applications: $e'),
        ),
      ),
    );
  }
}
