import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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
  Future<void> setReview(String id, int rating, {String? comment});
}

class FirestoreTransactionRepository implements TransactionRepository {
  FirestoreTransactionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('transactions');

  @override
  Stream<List<TransactionModel>> watchUserTransactions(String userId) {
    // Firestore doesn't support OR queries across different fields without
    // composite workarounds, so we merge (buyerId == userId) and
    // (sellerId == userId) streams client-side.
    final buyerQuery = _col
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
    final sellerQuery = _col
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    late final StreamController<List<TransactionModel>> controller;
    StreamSubscription? buyerSub;
    StreamSubscription? sellerSub;

    QuerySnapshot<Map<String, dynamic>>? buyerSnap;
    QuerySnapshot<Map<String, dynamic>>? sellerSnap;

    void emit() {
      final byId = <String, TransactionModel>{};
      final addAll = (QuerySnapshot<Map<String, dynamic>>? snap) {
        if (snap == null) return;
        for (final doc in snap.docs) {
          byId[doc.id] = TransactionModel.fromFirestore(doc);
        }
      };
      addAll(buyerSnap);
      addAll(sellerSnap);

      final list = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(list);
    }

    controller = StreamController<List<TransactionModel>>.broadcast(
      onListen: () {
        buyerSub = buyerQuery.listen((s) {
          buyerSnap = s;
          emit();
        }, onError: controller.addError);
        sellerSub = sellerQuery.listen((s) {
          sellerSnap = s;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await buyerSub?.cancel();
        await sellerSub?.cancel();
        buyerSub = null;
        sellerSub = null;
      },
    );

    return controller.stream;
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

  @override
  Future<void> setReview(String id, int rating, {String? comment}) async {
    await _col.doc(id).update({
      'status': TransactionStatus.reviewed.name,
      'rating': rating,
      'reviewComment': comment ?? '',
    });
  }
}

