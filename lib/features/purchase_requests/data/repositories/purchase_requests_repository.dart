import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/core/constants/product_sizes.dart';

import '../models/purchase_request.dart';

enum PurchaseRequestMutationResult { updated, expired }

class PurchaseRequestsRepository {
  PurchaseRequestsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<PurchaseRequest>> watchUserRequests(String userId) {
    return _firestore
        .collection('purchase_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => PurchaseRequest.fromMap(doc.id, doc.data()))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Stream<List<PurchaseRequest>> watchShopRequests(String shopId) {
    final normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return Stream.value(const <PurchaseRequest>[]);
    }

    return _firestore
        .collection('purchase_requests')
        .where('shopId', isEqualTo: normalizedShopId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => PurchaseRequest.fromMap(doc.id, doc.data()))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Future<PurchaseRequest?> getRequestById(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) return null;

    final doc = await _firestore
        .collection('purchase_requests')
        .doc(normalizedId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return PurchaseRequest.fromMap(doc.id, data);
  }

  Future<PurchaseRequestMutationResult> acceptRequestByShop({
    required String requestId,
    required String actorUid,
    Duration? acceptanceWindow,
  }) {
    return _mutateRequestAndOrderStatus(
      requestId: requestId,
      targetStatus: 'accepted',
      actorUid: actorUid,
      acceptanceWindow: acceptanceWindow ?? const Duration(minutes: 30),
    );
  }

  Future<PurchaseRequestMutationResult> rejectRequestByShop({
    required String requestId,
    required String actorUid,
    String? rejectionReason,
  }) {
    return _mutateRequestAndOrderStatus(
      requestId: requestId,
      targetStatus: 'rejected',
      actorUid: actorUid,
      rejectionReason: rejectionReason,
    );
  }

  Future<PurchaseRequestMutationResult> payRequestByUser({
    required String requestId,
    required String actorUid,
  }) {
    return _mutateRequestAndOrderStatus(
      requestId: requestId,
      targetStatus: 'paid',
      actorUid: actorUid,
    );
  }

  Future<PurchaseRequestMutationResult> expireRequest({
    required String requestId,
  }) {
    return _mutateRequestAndOrderStatus(
      requestId: requestId,
      targetStatus: 'expired',
      actorUid: null,
    );
  }

  Future<PurchaseRequestMutationResult> _mutateRequestAndOrderStatus({
    required String requestId,
    required String targetStatus,
    required String? actorUid,
    Duration? acceptanceWindow,
    String? rejectionReason,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw ArgumentError('requestId cannot be empty');
    }

    final requestRef =
        _firestore.collection('purchase_requests').doc(normalizedRequestId);
    PurchaseRequestMutationResult mutationResult =
        PurchaseRequestMutationResult.updated;

    try {
      await _firestore.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists) {
          throw StateError('Purchase request not found.');
        }

        final requestData = requestSnap.data() ?? const <String, dynamic>{};
        final currentStatus = _normalizeStatus(requestData['status']);
        final orderId = (requestData['orderId'] ?? '').toString().trim();
        if (orderId.isEmpty) {
          throw StateError('Purchase request is missing orderId.');
        }
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) {
          throw StateError('Order not found for this request.');
        }
        final orderData = orderSnap.data() ?? const <String, dynamic>{};

        final resolvedStatus = _resolveTargetStatus(
          currentStatus: currentStatus,
          targetStatus: targetStatus,
          requestData: requestData,
        );
        if (targetStatus == 'paid' && resolvedStatus == 'expired') {
          mutationResult = PurchaseRequestMutationResult.expired;
        }

        final productId = (requestData['productId'] ?? '').toString().trim();
        final size = _normalizeSize(requestData['size']);
        final quantity = _readPositiveInt(
          requestData['quantity'],
          fallback:
              _readPositiveInt(requestData['reservationQty'], fallback: 1),
        );
        final reservationQty = _readPositiveInt(
          requestData['reservationQty'],
          fallback: quantity,
        );
        final currentlyReserved = requestData['reserved'] == true;

        DocumentReference<Map<String, dynamic>>? productRef;
        Map<String, int>? sizeStock;
        Map<String, int>? sizeReserved;
        Map<String, Map<String, dynamic>>? variants;
        var stockForSize = 0;
        var reservedForSize = 0;

        if (productId.isNotEmpty) {
          productRef = _firestore.collection('products').doc(productId);
          final productSnap = await tx.get(productRef);
          if (!productSnap.exists) {
            throw StateError('Product not found for this request.');
          }
          final productData = productSnap.data() ?? const <String, dynamic>{};
          sizeStock = _readIntMap(productData['sizeStock']);
          sizeReserved = _readIntMap(productData['sizeReserved']);
          variants = _readVariantMap(productData['variants']);

          final legacyStock = (productData['stock'] as num?)?.toInt() ?? 0;
          if (sizeStock.isEmpty) {
            sizeStock['M'] = legacyStock > 0 ? legacyStock : 10;
          }
          if (variants.isEmpty) {
            for (final entry in sizeStock.entries) {
              variants[entry.key] = <String, dynamic>{
                'stock': entry.value,
                'reserved': sizeReserved[entry.key] ?? 0,
                'price': null,
                'sku': null,
                'barcode': null,
              };
            }
          } else {
            for (final entry in variants.entries) {
              sizeStock[entry.key] =
                  _readPositiveInt(entry.value['stock'], fallback: 0);
              sizeReserved[entry.key] =
                  _readPositiveInt(entry.value['reserved'], fallback: 0);
            }
          }
          stockForSize = sizeStock[size] ?? 0;
          reservedForSize = sizeReserved[size] ?? 0;
        }

        final requestUpdate = _buildRequestUpdatePayload(
          status: resolvedStatus,
          actorUid: actorUid,
          acceptanceWindow: acceptanceWindow,
          rejectionReason: rejectionReason,
        );

        if (resolvedStatus == 'accepted') {
          if (productRef == null ||
              sizeStock == null ||
              sizeReserved == null ||
              variants == null) {
            throw StateError(
              'Purchase request is missing productId/size/quantity.',
            );
          }
          final available = stockForSize - reservedForSize;
          if (available < quantity) {
            throw StateError(
              'Not enough stock for size $size. Available: $available.',
            );
          }

          final nextReserved = reservedForSize + quantity;
          sizeReserved[size] = nextReserved;
          variants[size] = _variantWith(
            variants[size],
            stock: sizeStock[size] ?? 0,
            reserved: nextReserved,
          );
          tx.set(
            productRef,
            {
              'variants': variants,
              'hasVariants': variants.length > 1,
              'sizeStock': sizeStock,
              'sizeReserved': sizeReserved,
              'stock': _sumMapValues(sizeStock),
              'lastReservationRequestId': normalizedRequestId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          requestUpdate['reserved'] = true;
          requestUpdate['reservedAt'] = FieldValue.serverTimestamp();
          requestUpdate['reservationQty'] = quantity;
        } else if (resolvedStatus == 'rejected' ||
            resolvedStatus == 'expired') {
          if (currentlyReserved &&
              productRef != null &&
              sizeReserved != null &&
              sizeStock != null &&
              variants != null) {
            var nextReserved = reservedForSize - reservationQty;
            if (nextReserved < 0) nextReserved = 0;
            sizeReserved[size] = nextReserved;
            variants[size] = _variantWith(
              variants[size],
              stock: sizeStock[size] ?? 0,
              reserved: nextReserved,
            );
            tx.set(
              productRef,
              {
                'variants': variants,
                'hasVariants': variants.length > 1,
                'sizeStock': sizeStock,
                'sizeReserved': sizeReserved,
                'lastReservationRequestId': normalizedRequestId,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
          requestUpdate['reserved'] = false;
          requestUpdate['reservationQty'] = reservationQty;
        } else if (resolvedStatus == 'paid') {
          if (productRef == null ||
              sizeStock == null ||
              sizeReserved == null ||
              variants == null) {
            throw StateError(
              'Purchase request is missing productId/size/quantity.',
            );
          }

          var nextReserved = reservedForSize;
          if (currentlyReserved) {
            nextReserved = reservedForSize - reservationQty;
            if (nextReserved < 0) nextReserved = 0;
          } else {
            final available = stockForSize - reservedForSize;
            if (available < reservationQty) {
              throw StateError(
                'Not enough stock for size $size to complete payment.',
              );
            }
          }

          final nextStock = stockForSize - reservationQty;
          if (nextStock < 0) {
            throw StateError('Stock cannot become negative for size $size.');
          }

          sizeReserved[size] = nextReserved;
          sizeStock[size] = nextStock;
          variants[size] = _variantWith(
            variants[size],
            stock: nextStock,
            reserved: nextReserved,
          );
          tx.set(
            productRef,
            {
              'variants': variants,
              'hasVariants': variants.length > 1,
              'sizeStock': sizeStock,
              'sizeReserved': sizeReserved,
              'stock': _sumMapValues(sizeStock),
              'lastReservationRequestId': normalizedRequestId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          requestUpdate['reserved'] = false;
          requestUpdate['reservationQty'] = reservationQty;
        }

        tx.set(
          requestRef,
          requestUpdate,
          SetOptions(merge: true),
        );

        final shopIds = <String>{};
        final existingShopIds = orderData['shopIds'];
        if (existingShopIds is List) {
          for (final value in existingShopIds) {
            final normalized = value.toString().trim();
            if (normalized.isNotEmpty) {
              shopIds.add(normalized);
            }
          }
        }
        final currentShopId = (requestData['shopId'] ?? '').toString().trim();
        if (currentShopId.isNotEmpty) {
          shopIds.add(currentShopId);
        }

        final summary = _applyStatusTransition(
          summary: _readStatusSummary(
            orderData['statusSummary'],
            fallbackTotal: _fallbackOrderTotal(orderData),
          ),
          fromStatus: currentStatus,
          toStatus: resolvedStatus,
        );
        final currentOrderStatus = _normalizeStatus(orderData['status']);
        final nextOrderStatus = _resolveOrderStatus(
          currentOrderStatus: currentOrderStatus,
          summary: summary,
        );
        final nextPaymentStatus = _derivePaymentStatusFromSummary(summary);
        tx.set(
          orderRef,
          {
            'status': nextOrderStatus,
            'paymentStatus': nextPaymentStatus,
            'shopIds': shopIds.toList(growable: false),
            'lastRequestUpdateId': normalizedRequestId,
            'lastRequestStatus': resolvedStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            'statusSummary': summary,
          },
          SetOptions(merge: true),
        );

        if (resolvedStatus == 'expired') {
          mutationResult = PurchaseRequestMutationResult.expired;
        }
      });
    } on FirebaseException catch (e) {
      final message = e.message?.trim() ?? '';
      final shouldFallback = e.code == 'unknown' &&
          (message.isEmpty ||
              message == 'null' ||
              message.contains('Transactions require all reads'));
      if (shouldFallback) {
        return _mutateWithoutTransaction(
          requestRef: requestRef,
          requestId: normalizedRequestId,
          targetStatus: targetStatus,
          actorUid: actorUid,
          acceptanceWindow: acceptanceWindow,
          rejectionReason: rejectionReason,
        );
      }
      rethrow;
    }

    return mutationResult;
  }

  Future<PurchaseRequestMutationResult> _mutateWithoutTransaction({
    required DocumentReference<Map<String, dynamic>> requestRef,
    required String requestId,
    required String targetStatus,
    required String? actorUid,
    Duration? acceptanceWindow,
    String? rejectionReason,
  }) async {
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw StateError('Purchase request not found.');
    }

    final requestData = requestSnap.data() ?? const <String, dynamic>{};
    final currentStatus = _normalizeStatus(requestData['status']);
    final orderId = (requestData['orderId'] ?? '').toString().trim();
    if (orderId.isEmpty) {
      throw StateError('Purchase request is missing orderId.');
    }
    final orderRef = _firestore.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw StateError('Order not found for this request.');
    }
    final orderData = orderSnap.data() ?? const <String, dynamic>{};

    final resolvedStatus = _resolveTargetStatus(
      currentStatus: currentStatus,
      targetStatus: targetStatus,
      requestData: requestData,
    );
    var mutationResult = PurchaseRequestMutationResult.updated;
    if (targetStatus == 'paid' && resolvedStatus == 'expired') {
      mutationResult = PurchaseRequestMutationResult.expired;
    }

    final productId = (requestData['productId'] ?? '').toString().trim();
    final size = _normalizeSize(requestData['size']);
    final quantity = _readPositiveInt(
      requestData['quantity'],
      fallback: _readPositiveInt(requestData['reservationQty'], fallback: 1),
    );
    final reservationQty = _readPositiveInt(
      requestData['reservationQty'],
      fallback: quantity,
    );
    final currentlyReserved = requestData['reserved'] == true;

    DocumentReference<Map<String, dynamic>>? productRef;
    Map<String, int>? sizeStock;
    Map<String, int>? sizeReserved;
    Map<String, Map<String, dynamic>>? variants;
    var stockForSize = 0;
    var reservedForSize = 0;

    if (productId.isNotEmpty) {
      productRef = _firestore.collection('products').doc(productId);
      final productSnap = await productRef.get();
      if (!productSnap.exists) {
        throw StateError('Product not found for this request.');
      }

      final productData = productSnap.data() ?? const <String, dynamic>{};
      sizeStock = _readIntMap(productData['sizeStock']);
      sizeReserved = _readIntMap(productData['sizeReserved']);
      variants = _readVariantMap(productData['variants']);

      final legacyStock = (productData['stock'] as num?)?.toInt() ?? 0;
      if (sizeStock.isEmpty) {
        sizeStock['M'] = legacyStock > 0 ? legacyStock : 10;
      }
      if (variants.isEmpty) {
        for (final entry in sizeStock.entries) {
          variants[entry.key] = <String, dynamic>{
            'stock': entry.value,
            'reserved': sizeReserved[entry.key] ?? 0,
            'price': null,
            'sku': null,
            'barcode': null,
          };
        }
      } else {
        for (final entry in variants.entries) {
          sizeStock[entry.key] =
              _readPositiveInt(entry.value['stock'], fallback: 0);
          sizeReserved[entry.key] =
              _readPositiveInt(entry.value['reserved'], fallback: 0);
        }
      }

      stockForSize = sizeStock[size] ?? 0;
      reservedForSize = sizeReserved[size] ?? 0;
    }

    final requestUpdate = _buildRequestUpdatePayload(
      status: resolvedStatus,
      actorUid: actorUid,
      acceptanceWindow: acceptanceWindow,
      rejectionReason: rejectionReason,
    );

    Map<String, dynamic>? productUpdatePayload;
    if (resolvedStatus == 'accepted') {
      if (productRef == null ||
          sizeStock == null ||
          sizeReserved == null ||
          variants == null) {
        throw StateError(
            'Purchase request is missing productId/size/quantity.');
      }

      final available = stockForSize - reservedForSize;
      if (available < quantity) {
        throw StateError(
            'Not enough stock for size $size. Available: $available.');
      }

      final nextReserved = reservedForSize + quantity;
      sizeReserved[size] = nextReserved;
      variants[size] = _variantWith(
        variants[size],
        stock: sizeStock[size] ?? 0,
        reserved: nextReserved,
      );
      productUpdatePayload = {
        'variants': variants,
        'hasVariants': variants.length > 1,
        'sizeStock': sizeStock,
        'sizeReserved': sizeReserved,
        'stock': _sumMapValues(sizeStock),
        'lastReservationRequestId': requestId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      requestUpdate['reserved'] = true;
      requestUpdate['reservedAt'] = FieldValue.serverTimestamp();
      requestUpdate['reservationQty'] = quantity;
    } else if (resolvedStatus == 'rejected' || resolvedStatus == 'expired') {
      if (currentlyReserved &&
          productRef != null &&
          sizeReserved != null &&
          sizeStock != null &&
          variants != null) {
        var nextReserved = reservedForSize - reservationQty;
        if (nextReserved < 0) nextReserved = 0;
        sizeReserved[size] = nextReserved;
        variants[size] = _variantWith(
          variants[size],
          stock: sizeStock[size] ?? 0,
          reserved: nextReserved,
        );
        productUpdatePayload = {
          'variants': variants,
          'hasVariants': variants.length > 1,
          'sizeStock': sizeStock,
          'sizeReserved': sizeReserved,
          'lastReservationRequestId': requestId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }
      requestUpdate['reserved'] = false;
      requestUpdate['reservationQty'] = reservationQty;
    } else if (resolvedStatus == 'paid') {
      if (productRef == null ||
          sizeStock == null ||
          sizeReserved == null ||
          variants == null) {
        throw StateError(
            'Purchase request is missing productId/size/quantity.');
      }

      var nextReserved = reservedForSize;
      if (currentlyReserved) {
        nextReserved = reservedForSize - reservationQty;
        if (nextReserved < 0) nextReserved = 0;
      } else {
        final available = stockForSize - reservedForSize;
        if (available < reservationQty) {
          throw StateError(
            'Not enough stock for size $size to complete payment.',
          );
        }
      }

      final nextStock = stockForSize - reservationQty;
      if (nextStock < 0) {
        throw StateError('Stock cannot become negative for size $size.');
      }

      sizeReserved[size] = nextReserved;
      sizeStock[size] = nextStock;
      variants[size] = _variantWith(
        variants[size],
        stock: nextStock,
        reserved: nextReserved,
      );
      productUpdatePayload = {
        'variants': variants,
        'hasVariants': variants.length > 1,
        'sizeStock': sizeStock,
        'sizeReserved': sizeReserved,
        'stock': _sumMapValues(sizeStock),
        'lastReservationRequestId': requestId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      requestUpdate['reserved'] = false;
      requestUpdate['reservationQty'] = reservationQty;
    }

    final shopIds = <String>{};
    final existingShopIds = orderData['shopIds'];
    if (existingShopIds is List) {
      for (final value in existingShopIds) {
        final normalized = value.toString().trim();
        if (normalized.isNotEmpty) {
          shopIds.add(normalized);
        }
      }
    }
    final currentShopId = (requestData['shopId'] ?? '').toString().trim();
    if (currentShopId.isNotEmpty) {
      shopIds.add(currentShopId);
    }

    final summary = _applyStatusTransition(
      summary: _readStatusSummary(
        orderData['statusSummary'],
        fallbackTotal: _fallbackOrderTotal(orderData),
      ),
      fromStatus: currentStatus,
      toStatus: resolvedStatus,
    );
    final currentOrderStatus = _normalizeStatus(orderData['status']);
    final nextOrderStatus = _resolveOrderStatus(
      currentOrderStatus: currentOrderStatus,
      summary: summary,
    );
    final nextPaymentStatus = _derivePaymentStatusFromSummary(summary);

    final batch = _firestore.batch();
    if (productRef != null && productUpdatePayload != null) {
      batch.set(productRef, productUpdatePayload, SetOptions(merge: true));
    }
    batch.set(requestRef, requestUpdate, SetOptions(merge: true));
    batch.set(
        orderRef,
        {
          'status': nextOrderStatus,
          'paymentStatus': nextPaymentStatus,
          'shopIds': shopIds.toList(growable: false),
          'lastRequestUpdateId': requestId,
          'lastRequestStatus': resolvedStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'statusSummary': summary,
        },
        SetOptions(merge: true));
    await batch.commit();

    if (resolvedStatus == 'expired') {
      mutationResult = PurchaseRequestMutationResult.expired;
    }
    return mutationResult;
  }

  String _resolveTargetStatus({
    required String currentStatus,
    required String targetStatus,
    required Map<String, dynamic> requestData,
  }) {
    if (targetStatus == 'accepted') {
      if (currentStatus != 'pending' && currentStatus != 'requested') {
        throw StateError('Only pending requests can be accepted.');
      }
      return 'accepted';
    }

    if (targetStatus == 'rejected') {
      if (currentStatus == 'paid' ||
          currentStatus == 'rejected' ||
          currentStatus == 'expired' ||
          currentStatus == 'canceled') {
        throw StateError('Request is already finalized.');
      }
      return 'rejected';
    }

    if (targetStatus == 'paid') {
      if (currentStatus == 'paid') {
        throw StateError('Request is already paid.');
      }
      if (currentStatus != 'accepted') {
        throw StateError('Only accepted requests can be paid.');
      }

      final expiresAt = _parseDate(requestData['expiresAt']);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return 'expired';
      }
      return 'paid';
    }

    if (targetStatus == 'expired') {
      if (currentStatus != 'accepted') {
        throw StateError('Only accepted requests can expire.');
      }
      final expiresAt = _parseDate(requestData['expiresAt']);
      if (expiresAt == null || DateTime.now().isBefore(expiresAt)) {
        throw StateError('Request has not expired yet.');
      }
      return 'expired';
    }

    return targetStatus;
  }

  Map<String, dynamic> _buildRequestUpdatePayload({
    required String status,
    required String? actorUid,
    Duration? acceptanceWindow,
    String? rejectionReason,
  }) {
    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'accepted') {
      final expiresAt =
          DateTime.now().add(acceptanceWindow ?? const Duration(minutes: 30));
      payload['acceptedAt'] = FieldValue.serverTimestamp();
      payload['acceptedBy'] = actorUid;
      payload['expiresAt'] = Timestamp.fromDate(expiresAt);
      payload['rejectionReason'] = null;
    } else if (status == 'rejected') {
      final reason = (rejectionReason ?? '').trim();
      payload['rejectedAt'] = FieldValue.serverTimestamp();
      payload['rejectedBy'] = actorUid;
      payload['rejectionReason'] =
          reason.isEmpty ? 'Rejected by shop.' : reason;
      payload['expiresAt'] = null;
    } else if (status == 'paid') {
      payload['paidAt'] = FieldValue.serverTimestamp();
      payload['paidBy'] = actorUid;
      payload['expiresAt'] = null;
    } else if (status == 'expired') {
      payload['expiredAt'] = FieldValue.serverTimestamp();
      payload['expiresAt'] = null;
    }

    return payload;
  }

  Map<String, dynamic> _emptyStatusSummary() {
    return <String, dynamic>{
      'total': 0,
      'pending': 0,
      'requested': 0,
      'accepted': 0,
      'paid': 0,
      'rejected': 0,
      'canceled': 0,
      'expired': 0,
      'other': 0,
    };
  }

  Map<String, dynamic> _readStatusSummary(
    dynamic value, {
    required int fallbackTotal,
  }) {
    final summary = _emptyStatusSummary();
    if (value is Map) {
      for (final key in summary.keys) {
        final rawValue = value[key];
        if (rawValue is int && rawValue >= 0) {
          summary[key] = rawValue;
        } else if (rawValue is num && rawValue.toInt() >= 0) {
          summary[key] = rawValue.toInt();
        }
      }
    }

    final computedTotal = (summary['pending'] as int) +
        (summary['requested'] as int) +
        (summary['accepted'] as int) +
        (summary['paid'] as int) +
        (summary['rejected'] as int) +
        (summary['canceled'] as int) +
        (summary['expired'] as int) +
        (summary['other'] as int);

    final currentTotal = summary['total'] as int;
    summary['total'] = [
      currentTotal,
      computedTotal,
      fallbackTotal,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return summary;
  }

  int _fallbackOrderTotal(Map<String, dynamic> orderData) {
    final items = orderData['items'];
    if (items is List && items.isNotEmpty) {
      return items.length;
    }
    return 1;
  }

  Map<String, dynamic> _applyStatusTransition({
    required Map<String, dynamic> summary,
    required String fromStatus,
    required String toStatus,
  }) {
    final next = Map<String, dynamic>.from(summary);
    final normalizedFrom = _normalizeStatus(fromStatus);
    final normalizedTo = _normalizeStatus(toStatus);
    if (normalizedFrom == normalizedTo) {
      return next;
    }

    if (next.containsKey(normalizedFrom)) {
      final current = next[normalizedFrom] as int? ?? 0;
      next[normalizedFrom] = current > 0 ? current - 1 : 0;
    } else {
      final other = next['other'] as int? ?? 0;
      next['other'] = other > 0 ? other - 1 : 0;
    }

    if (next.containsKey(normalizedTo)) {
      next[normalizedTo] = (next[normalizedTo] as int? ?? 0) + 1;
    } else {
      next['other'] = (next['other'] as int? ?? 0) + 1;
    }

    final computedTotal = (next['pending'] as int) +
        (next['requested'] as int) +
        (next['accepted'] as int) +
        (next['paid'] as int) +
        (next['rejected'] as int) +
        (next['canceled'] as int) +
        (next['expired'] as int) +
        (next['other'] as int);
    final currentTotal = next['total'] as int? ?? 0;
    next['total'] = currentTotal > computedTotal ? currentTotal : computedTotal;
    if ((next['total'] as int) <= 0) {
      next['total'] = 1;
    }
    return next;
  }

  String _resolveOrderStatus({
    required String currentOrderStatus,
    required Map<String, dynamic> summary,
  }) {
    const terminalOrManual = <String>{
      'preparing',
      'delivered',
      'canceled',
    };
    if (terminalOrManual.contains(currentOrderStatus)) {
      return currentOrderStatus;
    }
    return _deriveOrderStatusFromSummary(summary);
  }

  String _deriveOrderStatusFromSummary(Map<String, dynamic> summary) {
    final total = summary['total'] as int? ?? 0;
    final pending = summary['pending'] as int? ?? 0;
    final requested = summary['requested'] as int? ?? 0;
    final accepted = summary['accepted'] as int? ?? 0;
    final paid = summary['paid'] as int? ?? 0;
    final rejected = summary['rejected'] as int? ?? 0;
    final canceled = summary['canceled'] as int? ?? 0;
    final expired = summary['expired'] as int? ?? 0;

    if (rejected + canceled + expired > 0) {
      return 'rejected';
    }

    if (total > 0 && paid == total) {
      return 'paid';
    }

    final activePending = pending + requested;
    if ((accepted + paid) > 0 && activePending > 0) {
      return 'processing';
    }

    if (total > 0 && (accepted + paid) == total) {
      return 'accepted';
    }

    return 'pending';
  }

  String _derivePaymentStatusFromSummary(Map<String, dynamic> summary) {
    final total = summary['total'] as int? ?? 0;
    final paid = summary['paid'] as int? ?? 0;
    if (total <= 0 || paid <= 0) return 'unpaid';
    if (paid >= total) return 'paid';
    return 'partial';
  }

  String _normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();
    if (status.isEmpty) return 'pending';
    return status;
  }

  String _normalizeSize(dynamic value) {
    return normalizeProductSize((value ?? '').toString(), fallback: 'M');
  }

  int _readPositiveInt(dynamic value, {required int fallback}) {
    if (value is int && value > 0) return value;
    if (value is num && value.toInt() > 0) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    return fallback;
  }

  Map<String, int> _readIntMap(dynamic value) {
    if (value is! Map) return <String, int>{};
    final result = <String, int>{};
    value.forEach((k, v) {
      final normalizedKey = _normalizeSize(k);
      final intValue = v is num ? v.toInt() : int.tryParse(v.toString());
      if (intValue == null || intValue < 0) return;
      result[normalizedKey] = intValue;
    });
    return result;
  }

  Map<String, Map<String, dynamic>> _readVariantMap(dynamic value) {
    if (value is! Map) return <String, Map<String, dynamic>>{};
    final result = <String, Map<String, dynamic>>{};
    value.forEach((rawKey, rawValue) {
      if (rawValue is! Map) return;
      final key = _normalizeSize(rawKey);
      result[key] = <String, dynamic>{
        'stock': _readPositiveInt(rawValue['stock'], fallback: 0),
        'reserved': _readPositiveInt(rawValue['reserved'], fallback: 0),
        'price': rawValue['price'],
        'sku': rawValue['sku'],
        'barcode': rawValue['barcode'],
      };
    });
    return result;
  }

  Map<String, dynamic> _variantWith(
    Map<String, dynamic>? existing, {
    required int stock,
    required int reserved,
  }) {
    return <String, dynamic>{
      'stock': stock,
      'reserved': reserved,
      'price': existing?['price'],
      'sku': existing?['sku'],
      'barcode': existing?['barcode'],
    };
  }

  int _sumMapValues(Map<String, int> map) {
    var total = 0;
    for (final value in map.values) {
      total += value;
    }
    return total;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
