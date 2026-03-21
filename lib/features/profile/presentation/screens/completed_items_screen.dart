import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

class CompletedItemsScreen extends ConsumerWidget {
  const CompletedItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    final txAsync = ref.watch(userTransactionsProvider(user.uid));

    final completedRequestsStream = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('sellerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: completedRequestsStream,
        builder: (context, reqSnap) {
          final requestDocs = reqSnap.data?.docs ?? const [];

          return txAsync.when(
            data: (txs) {
              final completedTx = txs
                  .where(
                    (t) =>
                        t.status == TransactionStatus.completed ||
                        t.status == TransactionStatus.reviewed,
                  )
                  .toList();

              final isEmpty = completedTx.isEmpty && requestDocs.isEmpty;
              if (isEmpty) {
                return const Center(
                  child: Text(
                    '完了した項目はありません',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (requestDocs.isNotEmpty) ...[
                    const Text(
                      '完了した依頼',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...requestDocs.map((d) {
                      final data = d.data();
                      final title = data['serviceTitle'] as String? ?? 'サービス';
                      final buyerName = data['buyerName'] as String? ?? '購入者';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final time = createdAt == null
                          ? ''
                          : DateFormat('M/d HH:mm').format(createdAt);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(title),
                        subtitle: Text('依頼者: $buyerName ${time.isEmpty ? '' : '・$time'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/seller/requests/${d.id}'),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                  ],
                  if (completedTx.isNotEmpty) ...[
                    const Text(
                      '完了した取引',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...completedTx.map((t) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('¥${NumberFormat('#,###').format(t.price)}'),
                        subtitle: Text(t.status == TransactionStatus.reviewed ? 'レビュー済み' : '完了'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/transactions/${t.id}'),
                      );
                    }),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        '完了',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
    );
  }
}

