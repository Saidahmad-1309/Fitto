import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/purchase_requests/data/models/purchase_request.dart';
import 'package:fitto/features/purchase_requests/data/repositories/purchase_requests_repository.dart';

import '../controllers/purchase_requests_providers.dart';

class PurchaseRequestDetailsScreen extends ConsumerWidget {
  const PurchaseRequestDetailsScreen({
    super.key,
    required this.requestId,
    this.showPaymentActions = true,
  });

  final String requestId;
  final bool showPaymentActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final requestAsync =
        ref.watch(purchaseRequestDetailsProvider(requestId.trim()));

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: requestAsync.when(
          data: (request) {
            if (request == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Request not found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This request may have been removed or the ID is invalid.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to Requests'),
                    ),
                  ],
                ),
              );
            }
            final isRequestOwner = currentUser?.uid == request.userId;
            return ListView(
              children: [
                Text(
                  request.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text('Status: ${request.status}'),
                const SizedBox(height: 8),
                Text('Created: ${request.createdAt.toIso8601String()}'),
                const SizedBox(height: 8),
                Text('Quantity: ${request.quantity}'),
                const SizedBox(height: 8),
                Text('Size: ${request.size}'),
                if (request.expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.isExpired
                        ? 'Expired at: ${request.expiresAt!.toIso8601String()}'
                        : 'Expires at: ${request.expiresAt!.toIso8601String()}',
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Status Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ..._buildTimeline(request),
                if ((request.shopId ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Shop ID: ${request.shopId}'),
                ],
                if ((request.productId ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Product ID: ${request.productId}'),
                ],
                if ((request.orderId ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Order ID: ${request.orderId}'),
                ],
                if (request.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(request.description),
                ],
                if (showPaymentActions && isRequestOwner) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: request.canPayNow
                          ? () async {
                              try {
                                final result = await ref
                                    .read(purchaseRequestActionsProvider)
                                    .pay(request.id);
                                if (!context.mounted) return;

                                if (result ==
                                    PurchaseRequestMutationResult.expired) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Request expired before payment.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Payment marked as successful.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Payment failed: $e'),
                                  ),
                                );
                              }
                            }
                          : null,
                      child:
                          Text(request.canPayNow ? 'Pay Now' : 'Not Eligible'),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const LoadingView(message: 'Loading request...'),
          error: (e, _) => ErrorView(message: 'Failed to load request: $e'),
        ),
      ),
    );
  }

  List<Widget> _buildTimeline(PurchaseRequest request) {
    final normalized = request.status.toLowerCase();
    final steps = <_TimelineStep>[
      const _TimelineStep(key: 'pending', label: 'Request created'),
      const _TimelineStep(key: 'accepted', label: 'Accepted'),
      const _TimelineStep(key: 'paid', label: 'Paid'),
    ];

    if (normalized == 'canceled' || normalized == 'rejected') {
      return [
        _timelineTile(
          label: 'Request created',
          state: _StepState.done,
        ),
        _timelineTile(
          label: normalized == 'rejected' ? 'Rejected' : 'Canceled',
          state: _StepState.current,
        ),
      ];
    }

    int currentIndex = 0;
    if (normalized == 'accepted') currentIndex = 1;
    if (normalized == 'paid') currentIndex = 2;

    final tiles = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final state = i < currentIndex
          ? _StepState.done
          : (i == currentIndex ? _StepState.current : _StepState.pending);
      tiles.add(_timelineTile(label: steps[i].label, state: state));
    }
    return tiles;
  }

  Widget _timelineTile({
    required String label,
    required _StepState state,
  }) {
    final icon = switch (state) {
      _StepState.done => Icons.check_circle,
      _StepState.current => Icons.radio_button_checked,
      _StepState.pending => Icons.radio_button_unchecked,
    };
    final color = switch (state) {
      _StepState.done => Colors.green,
      _StepState.current => Colors.blue,
      _StepState.pending => Colors.grey,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
    );
  }
}

enum _StepState { done, current, pending }

class _TimelineStep {
  const _TimelineStep({required this.key, required this.label});

  final String key;
  final String label;
}
