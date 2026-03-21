import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/transaction_repository.dart';
import '../../domain/models/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return FirestoreTransactionRepository(FirebaseFirestore.instance);
});

final transactionDetailProvider =
    StreamProvider.family<TransactionModel, String>((ref, id) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('transactions')
      .doc(id)
      .snapshots()
      .where((doc) => doc.exists && doc.data() != null)
      .map((doc) => TransactionModel.fromFirestore(doc));
});

final userTransactionsProvider =
    StreamProvider.autoDispose.family<List<TransactionModel>, String>((ref, userId) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchUserTransactions(userId);
});
