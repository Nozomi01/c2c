import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/service.dart';

abstract class ServiceRepository {
  Stream<List<Service>> watchRecommended();
  Stream<List<Service>> watchByOwner(String ownerId);
  Future<Service> getById(String id);
  Future<String> create(Service service);
}

class FirestoreServiceRepository implements ServiceRepository {
  FirestoreServiceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('services');

  @override
  Stream<List<Service>> watchRecommended() {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (s) => s.docs.map(Service.fromFirestore).toList(),
        );
  }

  @override
  Stream<List<Service>> watchByOwner(String ownerId) {
    return _col.where('ownerId', isEqualTo: ownerId).snapshots().map(
          (s) => s.docs.map(Service.fromFirestore).toList(),
        );
  }

  @override
  Future<Service> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) {
      throw Exception('Service not found');
    }
    return Service.fromFirestore(doc);
  }

  @override
  Future<String> create(Service service) async {
    final doc = await _col.add({
      'ownerId': service.ownerId,
      'title': service.title,
      'description': service.description,
      'category': service.category,
      'price': service.price,
      'duration': service.duration,
      'location': service.location,
      'onlineAvailable': service.onlineAvailable,
      'offlineAvailable': service.offlineAvailable,
      'images': service.images,
      'rating': service.rating,
      'reviewCount': service.reviewCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}

