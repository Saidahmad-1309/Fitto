import 'package:cloud_firestore/cloud_firestore.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.city,
    this.description,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? city;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;

  factory Shop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtTs = data['createdAt'] as Timestamp?;
    return Shop(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      city: data['city'] as String?,
      description: data['description'] as String?,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: createdAtTs?.toDate(),
    );
  }
}
