import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/transaction.dart';

abstract class TransactionRepository {
  Stream<List<TransactionModel>> watchUserTransactions(String userId);
  Future<TransactionModel> getById(String id);
  Future<String> createPending({
    required String serviceId,
    required String buyerId,
    required String sellerId,
    required int price,
  });
  Future<void> updateStatus(String id, TransactionStatus status);
}

class FirestoreTransactionRepository implements TransactionRepository {
  FirestoreTransactionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('transactions');

  @override
  Stream<List<TransactionModel>> watchUserTransactions(String userId) {
    return _col
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TransactionModel.fromFirestore).toList());
  }

  @override
  Future<TransactionModel> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) throw Exception('Transaction not found');
    return TransactionModel.fromFirestore(doc);
  }

  @override
  Future<String> createPending({
    required String serviceId,
    required String buyerId,
    required String sellerId,
    required int price,
  }) async {
    final doc = await _col.add({
      'serviceId': serviceId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'price': price,
      'status': TransactionStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<void> updateStatus(String id, TransactionStatus status) async {
    await _col.doc(id).update({'status': status.name});
  }
}

