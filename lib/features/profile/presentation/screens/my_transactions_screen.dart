import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

class MyTransactionsScreen extends ConsumerWidget {
  const MyTransactionsScreen({super.key});

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: txAsync.when(
        data: (list) {
          final active = list
              .where(
                (t) => t.status == TransactionStatus.pending ||
                    t.status == TransactionStatus.paid ||
                    t.status == TransactionStatus.inProgress,
              )
              .toList();
          if (active.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.inventory_2_outlined, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    '取引中の取引はありません',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: active.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final tx = active[i];
              return ListTile(
                title: Text('¥${tx.price}'),
                subtitle: Text(_statusLabel(tx.status)),
                trailing: const Icon(AppIcons.chevron_right),
                onTap: () => context.push('/transactions/${tx.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      ),
    );
  }

  String _statusLabel(TransactionStatus s) {
    switch (s) {
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(AppIcons.chevron_left),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        '取引中',
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
