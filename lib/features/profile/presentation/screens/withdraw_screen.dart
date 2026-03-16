import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';

class WithdrawScreen extends StatelessWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '売上を出金',
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
      ),
      body: uid == null
          ? const Center(child: Text('ログインが必要です'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, snapshot) {
                  int balance = 0;
                  final doc = snapshot.data;
                  if (snapshot.hasData && doc != null && doc.data() != null) {
                    final data = doc.data()!;
                    final raw = data['walletBalance'];
                    if (raw is num) {
                      balance = raw.toInt();
                    }
                  }

                  final formatted = '¥${NumberFormat('#,###').format(balance)}';
                  final canWithdraw = balance > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '出金可能残高',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              formatted,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '出金先の銀行口座を登録すると、売上金を出金できます。ストライプと連携して安全に振り込みを行います。',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: !canWithdraw
                              ? null
                              : () async {
                                  try {
                                    await FirebaseFirestore.instance.runTransaction((tx) async {
                                      final ref =
                                          FirebaseFirestore.instance.collection('users').doc(uid);
                                      final snap = await tx.get(ref);
                                      final data = snap.data() ?? <String, dynamic>{};
                                      final raw = data['walletBalance'];
                                      final current = raw is num ? raw.toInt() : 0;
                                      if (current <= 0) return;

                                      // 全額出金として walletBalance を 0 に更新
                                      tx.update(ref, {'walletBalance': 0});

                                      // 出金履歴を保存
                                      final historyRef = ref.collection('withdrawals').doc();
                                      tx.set(historyRef, {
                                        'amount': current,
                                        'createdAt': FieldValue.serverTimestamp(),
                                        'status': 'requested',
                                      });
                                    });

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('出金リクエストを受け付けました。'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('出金に失敗しました: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('全額を出金リクエストする'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('キャンセル'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
