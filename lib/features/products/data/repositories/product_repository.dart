import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitto/features/products/data/models/product_model.dart';

class ProductRepository {
  ProductRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<ProductModel>> watchProducts({String? shopId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (shopId != null && shopId.isNotEmpty) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(ProductModel.fromDoc).toList(),
    );
  }

  Stream<ProductModel?> watchProduct(String productId) {
    return _firestore.collection('products').doc(productId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProductModel.fromDoc(doc);
    });
  }
}
