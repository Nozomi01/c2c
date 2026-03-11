import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/transaction.dart';
import '../../data/transaction_repository.dart';

String _transactionStatusLabel(TransactionStatus status) {
  switch (status) {
    case TransactionStatus.pending:
      return '保留中';
    case TransactionStatus.paid:
      return '支払い済み';
    case TransactionStatus.inProgress:
      return '提供中';
    case TransactionStatus.completed:
      return '完了';
    case TransactionStatus.reviewed:
      return 'レビュー済み';
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return FirestoreTransactionRepository(FirebaseFirestore.instance);
});

final transactionDetailProvider =
    FutureProvider.family<TransactionModel, String>((ref, id) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getById(id);
});

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('ログインが必要です')),
      );
    }

    if (transactionId == 'new') {
      return const _NewTransactionFlow();
    }

    final txAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('取引の詳細'),
      ),
      body: txAsync.when(
        data: (tx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('金額: ¥${tx.price}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('ステータス: ${_transactionStatusLabel(tx.status)}'),
              const SizedBox(height: 24),
              const Text('進行状況'),
              const SizedBox(height: 8),
              const _StepTimeline(),
            ],
          ),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, st) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

class _NewTransactionFlow extends StatelessWidget {
  const _NewTransactionFlow();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('購入手続き'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stripe決済（エスクロー）を開始します。'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Call Cloud Function to create PaymentIntent + Transaction
              },
              child: const Text('支払い方法を選択して支払う'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTimeline extends StatelessWidget {
  const _StepTimeline();

  @override
  Widget build(BuildContext context) {
    final steps = [
      '支払い',
      'サービス提供中',
      '完了',
      'レビュー',
    ];

    return Column(
      children: steps.map((s) {
        return ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(s),
        );
      }).toList(),
    );
  }
}

