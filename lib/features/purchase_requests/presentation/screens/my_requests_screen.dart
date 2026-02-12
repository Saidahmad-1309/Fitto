import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/navigation/app_routes.dart';
import 'package:fitto/core/navigation/root_route_observer.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/purchase_requests/data/models/purchase_request.dart';
import 'package:fitto/features/purchase_requests/data/repositories/purchase_requests_repository.dart';

import '../controllers/purchase_requests_providers.dart';
import 'purchase_request_details_screen.dart';

class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  Timer? _ticker;
  String? _lastHandledRequestId;
  final Set<String> _expiringRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(myPurchaseRequestsProvider);
    final deepLinkRequestId = ref.watch(myRequestsDeepLinkRequestIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: requestsAsync.when(
          data: (requests) {
            _handleIncomingTargetRequest(
              requests: requests,
              initialRequestId: widget.initialRequestId,
              deepLinkRequestId: deepLinkRequestId,
            );
            _synchronizeExpiredRequests(requests);

            if (requests.isEmpty) {
              return const EmptyState(
                title: 'No requests yet',
                subtitle: 'Your accepted requests will appear here.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myPurchaseRequestsProvider);
                await ref.read(myPurchaseRequestsProvider.future);
              },
              child: ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final countdown = _buildCountdownText(request);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Status: ${request.status}'),
                          const SizedBox(height: 4),
                          Text(
                              'Created: ${request.createdAt.toIso8601String()}'),
                          const SizedBox(height: 4),
                          Text(
                              'Size: ${request.size}  Qty: ${request.quantity}'),
                          if (countdown != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              countdown,
                              style: TextStyle(
                                color: request.isExpired
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _openRequestDetails(request.id),
                                child: const Text('Details'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: request.canPayNow
                                    ? () => _onPayNow(request.id)
                                    : null,
                                child: Text(
                                  request.isExpired ? 'Expired' : 'Pay Now',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const LoadingView(message: 'Loading requests...'),
          error: (e, _) => ErrorView(message: 'Failed to load requests: $e'),
        ),
      ),
    );
  }

  void _handleIncomingTargetRequest({
    required List<PurchaseRequest> requests,
    String? initialRequestId,
    String? deepLinkRequestId,
  }) {
    final normalizedDeepLink = deepLinkRequestId?.trim();
    final normalizedInitial = initialRequestId?.trim();

    final candidate =
        (normalizedDeepLink != null && normalizedDeepLink.isNotEmpty)
            ? normalizedDeepLink
            : (normalizedInitial != null && normalizedInitial.isNotEmpty)
                ? normalizedInitial
                : null;

    if (candidate == null || candidate == _lastHandledRequestId) return;
    _lastHandledRequestId = candidate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (normalizedDeepLink != null && normalizedDeepLink.isNotEmpty) {
        ref.read(myRequestsDeepLinkRequestIdProvider.notifier).state = null;
      }

      final requestExists = requests.any(
        (request) => request.id == candidate,
      );
      if (!requestExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request was not found. Showing your requests list.'),
          ),
        );
        return;
      }

      _openRequestDetails(candidate);
    });
  }

  void _openRequestDetails(String requestId) {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) return;
    if (rootRouteObserver.isRouteOnTop(
      AppRoutes.purchaseRequestDetails,
      arguments: normalizedId,
    )) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.purchaseRequestDetails,
          arguments: normalizedId,
        ),
        builder: (_) => PurchaseRequestDetailsScreen(requestId: normalizedId),
      ),
    );
  }

  Future<void> _onPayNow(String requestId) async {
    try {
      final result = await ref.read(purchaseRequestActionsProvider).pay(
            requestId,
          );
      if (!mounted) return;

      if (result == PurchaseRequestMutationResult.expired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request expired before payment.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as successful.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  String? _buildCountdownText(PurchaseRequest request) {
    if (!request.isAccepted || request.expiresAt == null) return null;
    final remaining = request.expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    return 'Expires in ${_formatDuration(remaining)}';
  }

  void _synchronizeExpiredRequests(List<PurchaseRequest> requests) {
    for (final request in requests) {
      if (!request.isAccepted || !request.isExpired) continue;
      if (_expiringRequestIds.contains(request.id)) continue;
      _expiringRequestIds.add(request.id);

      Future<void>.microtask(() async {
        try {
          await ref.read(purchaseRequestActionsProvider).expire(request.id);
        } catch (_) {
          // Silent by design: stream refresh will retry when needed.
        } finally {
          _expiringRequestIds.remove(request.id);
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
