import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop.dart';

class ShopsRepository {
  ShopsRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<Shop>> watchActiveShops() {
    return _firestore
        .collection('shops')
        .where('approved', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Shop.fromDoc).toList());
  }

  Future<void> seedSampleShops() async {
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    final shop1 = _firestore.collection('shops').doc('fitto_tashkent');
    final shop2 = _firestore.collection('shops').doc('urban_corner_samarkand');
    final shop3 = _firestore.collection('shops').doc('classic_fit_bukhara');

    batch.set(shop1, {
      'name': 'Fitto Tashkent',
      'city': 'Tashkent',
      'description': 'Modern streetwear and daily outfits.',
      'ownerUid': 'seed_admin',
      'approved': true,
      'approvedBy': 'seed_admin',
      'approvedAt': now,
      'isActive': true,
      'createdAt': now,
    }, SetOptions(merge: true));

    batch.set(shop2, {
      'name': 'Urban Corner',
      'city': 'Samarkand',
      'description': 'Jeans, jackets, and shoes for everyday style.',
      'ownerUid': 'seed_admin',
      'approved': true,
      'approvedBy': 'seed_admin',
      'approvedAt': now,
      'isActive': true,
      'createdAt': now,
    }, SetOptions(merge: true));

    batch.set(shop3, {
      'name': 'Classic Fit',
      'city': 'Bukhara',
      'description': 'Formal and classic fashion essentials.',
      'ownerUid': 'seed_admin',
      'approved': true,
      'approvedBy': 'seed_admin',
      'approvedAt': now,
      'isActive': true,
      'createdAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
