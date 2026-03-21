import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
                      const SizedBox(height: 16),
                      FutureBuilder<HttpsCallableResult<dynamic>>(
                        future: FirebaseFunctions.instanceFor(region: 'asia-northeast1')
                            .httpsCallable('getStripeBalance')
                            .call({'userId': uid}),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }
                          if (snap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Stripe残高の取得に失敗しました: ${snap.error}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            );
                          }
                          final data = snap.data?.data as Map<String, dynamic>?;
                          final stripeAvailable = data?['availableAmount'] as int? ?? 0;
                          final stripeFormatted =
                              '¥${NumberFormat('#,###').format(stripeAvailable)}';
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Stripe出金可能残高',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  stripeFormatted,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '出金金額を入力',
                          hintText: '例: 3000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                          onPressed: () async {
                            final text = _amountController.text.trim();
                            final parsed = int.tryParse(text) ?? 0;
                            if (parsed <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('1円以上の出金金額を入力してください。')),
                              );
                              return;
                            }
                            if (parsed > balance) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('出金金額が残高（$formatted）を超えています。')),
                              );
                              return;
                            }
                                  try {
                                    await FirebaseFirestore.instance.runTransaction((tx) async {
                                      final ref =
                                          FirebaseFirestore.instance.collection('users').doc(uid);
                                      final snap = await tx.get(ref);
                                      final data = snap.data() ?? <String, dynamic>{};
                                      final raw = data['walletBalance'];
                                      final current = raw is num ? raw.toInt() : 0;
                                      final stripeAccountId = data['stripeAccountId'] as String?;
                                      if (current <= 0) return;
                                      if (stripeAccountId == null ||
                                          stripeAccountId.isEmpty) {
                                        throw Exception('Stripe口座が未連携です（出金にはStripe連携が必要です）');
                                      }

                                      // 出金履歴を保存
                                      final historyRef = ref.collection('withdrawals').doc();
                                      tx.set(historyRef, {
                                        'amount': parsed,
                                        'createdAt': FieldValue.serverTimestamp(),
                                        'status': 'requested',
                                        'stripeAccountId': stripeAccountId,
                                      });

                                      // Trigger Stripe payout (Cloud Function listens to this collection).
                                      final payoutRef = FirebaseFirestore.instance
                                          .collection('payout_requests')
                                          .doc();
                                      tx.set(payoutRef, {
                                        'userId': uid,
                                        'amount': parsed,
                                        'stripeAccountId': stripeAccountId,
                                        'status': 'requested',
                                        'createdAt': FieldValue.serverTimestamp(),
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
