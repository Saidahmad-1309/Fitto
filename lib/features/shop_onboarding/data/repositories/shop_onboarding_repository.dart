import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shops/data/models/shop.dart';
import '../models/shop_application.dart';

class ShopOnboardingRepository {
  ShopOnboardingRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<ShopApplication>> watchApplicationsByOwner(String ownerUid) {
    return _firestore
        .collection('shop_applications')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ShopApplication.fromDoc).toList());
  }

  Stream<List<ShopApplication>> watchPendingApplications() {
    return _firestore
        .collection('shop_applications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ShopApplication.fromDoc).toList());
  }

  Stream<ShopUserLink?> watchShopUserLink(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(null);
    }
    return Stream.fromFuture(getShopUserLink(normalizedUserId));
  }

  Future<ShopUserLink?> getShopUserLink(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    try {
      final directDoc =
          await _firestore.collection('shop_users').doc(normalizedUserId).get();
      if (directDoc.exists) {
        final link = ShopUserLink.fromDoc(directDoc);
        if (link.shopId.trim().isNotEmpty) return link;
      }
    } catch (_) {
      // Fallbacks below handle permission/data-shape differences.
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(normalizedUserId).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final shopId = (data['shopId'] as String?)?.trim() ?? '';
      if (shopId.isNotEmpty) {
        return ShopUserLink(
          userId: normalizedUserId,
          shopId: shopId,
          role: ((data['shopRole'] as String?) ?? 'owner').trim().isEmpty
              ? 'owner'
              : (data['shopRole'] as String?)!,
        );
      }
    } catch (_) {
      // Continue fallback.
    }

    try {
      final approvedApps = await _firestore
          .collection('shop_applications')
          .where('ownerUid', isEqualTo: normalizedUserId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      if (approvedApps.docs.isNotEmpty) {
        return ShopUserLink(
          userId: normalizedUserId,
          shopId: approvedApps.docs.first.id,
          role: 'owner',
        );
      }
    } catch (_) {
      // No-op: final null below.
    }

    return null;
  }

  Future<void> submitApplication({
    required String ownerUid,
    required String shopName,
    required String city,
    required String description,
    String? contactPhone,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final pending = await _firestore
        .collection('shop_applications')
        .where('ownerUid', isEqualTo: normalizedOwnerUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pending.docs.isNotEmpty) {
      throw StateError('You already have a pending application.');
    }

    final doc = _firestore.collection('shop_applications').doc();
    await doc.set({
      'ownerUid': normalizedOwnerUid,
      'shopName': shopName,
      'city': city,
      'description': description,
      'contactPhone': contactPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
    });
  }

  Future<void> approveApplication({
    required ShopApplication application,
    required String adminUid,
  }) async {
    final batch = _firestore.batch();
    final appRef = _firestore.collection('shop_applications').doc(application.id);
    batch.update(appRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
    });

    final shopRef = _firestore.collection('shops').doc(application.id);
    batch.set(shopRef, {
      'name': application.shopName,
      'city': application.city,
      'description': application.description,
      'contactPhone': application.contactPhone,
      'ownerUid': application.ownerUid,
      'approved': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': adminUid,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'applicationId': application.id,
    }, SetOptions(merge: true));

    final shopUserRef =
        _firestore.collection('shop_users').doc(application.ownerUid);
    batch.set(shopUserRef, {
      'shopId': shopRef.id,
      'uid': application.ownerUid,
      'role': 'owner',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final ownerUserRef = _firestore.collection('users').doc(application.ownerUid);
    batch.set(ownerUserRef, {
      'shopId': shopRef.id,
      'shopRole': 'owner',
      'shopApproved': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> rejectApplication({
    required ShopApplication application,
    required String adminUid,
    String? reason,
  }) async {
    await _firestore.collection('shop_applications').doc(application.id).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'rejectionReason': reason,
    });
  }

  Future<Shop?> getApprovedShopForOwner(String ownerUid) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) return null;

    final directShopUserDoc =
        await _firestore.collection('shop_users').doc(normalizedOwnerUid).get();

    String? shopId = (directShopUserDoc.data()?['shopId'] as String?)?.trim();
    if (shopId == null || shopId.isEmpty) {
      try {
        final shopUsersSnapshot = await _firestore
            .collection('shop_users')
            .where('uid', isEqualTo: normalizedOwnerUid)
            .limit(1)
            .get();
        if (shopUsersSnapshot.docs.isNotEmpty) {
          shopId = (shopUsersSnapshot.docs.first.data()['shopId'] as String?)
              ?.trim();
        }
      } catch (_) {
        // Ignore fallback query failures and use direct-doc path only.
      }
    }
    if (shopId == null || shopId.isEmpty) return null;
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();
    if (!shopDoc.exists) return null;
    return Shop.fromDoc(shopDoc);
  }
}
