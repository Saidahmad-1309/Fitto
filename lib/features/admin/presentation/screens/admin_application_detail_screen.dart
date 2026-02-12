import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/shop_onboarding/data/models/shop_application.dart';
import 'package:fitto/features/shop_onboarding/presentation/controllers/shop_onboarding_providers.dart';

class AdminApplicationDetailScreen extends ConsumerStatefulWidget {
  const AdminApplicationDetailScreen({super.key, required this.application});

  final ShopApplication application;

  @override
  ConsumerState<AdminApplicationDetailScreen> createState() =>
      _AdminApplicationDetailScreenState();
}

class _AdminApplicationDetailScreenState
    extends ConsumerState<AdminApplicationDetailScreen> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access only')),
      );
    }
    final adminUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final repo = ref.read(shopOnboardingRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Application Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.application.shopName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('City: ${widget.application.city}'),
            const SizedBox(height: 8),
            Text('Owner: ${widget.application.ownerUid}'),
            if ((widget.application.contactPhone ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Phone: ${widget.application.contactPhone}'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(widget.application.description),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection reason (optional)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: adminUid == null
                        ? null
                        : () async {
                            await repo.approveApplication(
                              application: widget.application,
                              adminUid: adminUid,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: adminUid == null
                        ? null
                        : () async {
                            await repo.rejectApplication(
                              application: widget.application,
                              adminUid: adminUid,
                              reason: _reasonController.text.trim(),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
