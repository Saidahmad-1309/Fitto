import 'package:cloud_firestore/cloud_firestore.dart';

class ShopModel {
  const ShopModel({
    required this.shopId,
    required this.name,
    required this.address,
    required this.city,
    this.phone,
    this.instagram,
    required this.deliveryAvailable,
    required this.openingHours,
    this.createdAt,
  });

  final String shopId;
  final String name;
  final String address;
  final String city;
  final String? phone;
  final String? instagram;
  final bool deliveryAvailable;
  final String openingHours;
  final DateTime? createdAt;

  factory ShopModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final createdTs = map['createdAt'] as Timestamp?;
    return ShopModel(
      shopId: doc.id,
      name: (map['name'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      phone: map['phone'] as String?,
      instagram: map['instagram'] as String?,
      deliveryAvailable: (map['deliveryAvailable'] as bool?) ?? false,
      openingHours: (map['openingHours'] ?? '') as String,
      createdAt: createdTs?.toDate(),
    );
  }
}
