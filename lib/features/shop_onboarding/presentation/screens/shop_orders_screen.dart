import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/widgets/empty_state.dart';
import 'package:fitto/core/widgets/error_view.dart';
import 'package:fitto/core/widgets/loading_view.dart';
import 'package:fitto/features/orders/presentation/controllers/orders_providers.dart';
import 'package:fitto/features/purchase_requests/data/models/purchase_request.dart';
import 'package:fitto/features/purchase_requests/presentation/controllers/purchase_requests_providers.dart';
import 'package:fitto/features/purchase_requests/presentation/screens/purchase_request_details_screen.dart';

class ShopOrdersScreen extends ConsumerStatefulWidget {
  const ShopOrdersScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends ConsumerState<ShopOrdersScreen> {
  String? _requestActionInProgress;
  final Set<String> _expiringRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(shopPurchaseRequestsProvider(widget.shopId));

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Orders')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: requestsAsync.when(
          data: (requests) {
            _synchronizeExpiredRequests(requests);
            if (requests.isEmpty) {
              return const EmptyState(
                title: 'No incoming requests',
                subtitle: 'New customer requests will appear here.',
              );
            }

            return ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = requests[index];
                final busy = _requestActionInProgress == request.id;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Status: ${request.status}'),
                        const SizedBox(height: 4),
                        Text('Created: ${request.createdAt.toIso8601String()}'),
                        const SizedBox(height: 4),
                        Text('Size: ${request.size}  Qty: ${request.quantity}'),
                        if (request.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(request.description),
                        ],
                        if (request.isAccepted && !request.isExpired) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Waiting for customer payment',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PurchaseRequestDetailsScreen(
                                      requestId: request.id,
                                      showPaymentActions: false,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Details'),
                            ),
                            if (request.status.toLowerCase() == 'pending' ||
                                request.status.toLowerCase() == 'requested') ...[
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => _handleRequestStatus(
                                          requestId: request.id,
                                          approve: true,
                                        ),
                                child: Text(busy ? 'Working...' : 'Accept'),
                              ),
                              FilledButton.tonal(
                                onPressed: busy
                                    ? null
                                    : () => _handleRequestStatus(
                                          requestId: request.id,
                                          approve: false,
                                        ),
                                child: Text(busy ? 'Working...' : 'Reject'),
                              ),
                            ],
                            if (request.status.toLowerCase() == 'paid' &&
                                request.orderId != null &&
                                request.orderId!.trim().isNotEmpty) ...[
                              FilledButton.tonal(
                                onPressed: busy
                                    ? null
                                    : () => _updateShopOrderStatus(
                                          requestId: request.id,
                                          orderId: request.orderId!,
                                          shopId: request.shopId ?? '',
                                          nextStatus: 'preparing',
                                        ),
                                child: const Text('Preparing'),
                              ),
                              FilledButton.tonal(
                                onPressed: busy
                                    ? null
                                    : () => _updateShopOrderStatus(
                                          requestId: request.id,
                                          orderId: request.orderId!,
                                          shopId: request.shopId ?? '',
                                          nextStatus: 'delivered',
                                        ),
                                child: const Text('Delivered'),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => _updateShopOrderStatus(
                                          requestId: request.id,
                                          orderId: request.orderId!,
                                          shopId: request.shopId ?? '',
                                          nextStatus: 'canceled',
                                        ),
                                child: const Text('Cancel Order'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingView(message: 'Loading shop orders...'),
          error: (e, _) => ErrorView(message: 'Failed to load requests: $e'),
        ),
      ),
    );
  }

  Future<void> _handleRequestStatus({
    required String requestId,
    required bool approve,
  }) async {
    setState(() => _requestActionInProgress = requestId);
    try {
      final actions = ref.read(purchaseRequestActionsProvider);
      if (approve) {
        await actions.accept(requestId);
      } else {
        await actions.reject(requestId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Request accepted.' : 'Request rejected.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _requestActionInProgress = null);
      }
    }
  }

  Future<void> _updateShopOrderStatus({
    required String requestId,
    required String orderId,
    required String shopId,
    required String nextStatus,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedShopId = shopId.trim();
    if (normalizedOrderId.isEmpty || normalizedShopId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order/shop information is missing.')),
      );
      return;
    }

    setState(() => _requestActionInProgress = requestId);
    try {
      await ref.read(ordersControllerProvider).updateOrderStatusByShop(
            orderId: normalizedOrderId,
            shopId: normalizedShopId,
            nextStatus: nextStatus,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order moved to $nextStatus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _requestActionInProgress = null);
      }
    }
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
          // Silent by design: stream refresh will retry on next update.
        } finally {
          _expiringRequestIds.remove(request.id);
        }
      });
    }
  }
}

