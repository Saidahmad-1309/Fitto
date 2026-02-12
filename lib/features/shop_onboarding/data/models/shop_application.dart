import 'package:cloud_firestore/cloud_firestore.dart';

class ShopApplication {
  const ShopApplication({
    required this.id,
    required this.ownerUid,
    required this.shopName,
    required this.city,
    required this.description,
    this.contactPhone,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  final String id;
  final String ownerUid;
  final String shopName;
  final String city;
  final String description;
  final String? contactPhone;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  factory ShopApplication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ShopApplication(
      id: doc.id,
      ownerUid: (data['ownerUid'] ?? '') as String,
      shopName: (data['shopName'] ?? '') as String,
      city: (data['city'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      contactPhone: data['contactPhone'] as String?,
      status: (data['status'] ?? 'pending') as String,
      createdAt: _parseTimestamp(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: _parseTimestamp(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }
}

class ShopUserLink {
  const ShopUserLink({
    required this.userId,
    required this.shopId,
    required this.role,
  });

  final String userId;
  final String shopId;
  final String role;

  factory ShopUserLink.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ShopUserLink(
      userId: doc.id,
      shopId: (data['shopId'] ?? '') as String,
      role: (data['role'] ?? 'owner') as String,
    );
  }
}

DateTime? _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
