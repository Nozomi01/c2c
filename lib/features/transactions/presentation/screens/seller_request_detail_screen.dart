import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

final sellerRequestDetailProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
  (ref, requestId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('ログインが必要です');
    }
    final uid = user.uid;
    return FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(requestId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        throw Exception('依頼が見つかりませんでした');
      }
      final data = doc.data() ?? <String, dynamic>{};
      final sellerId = data['sellerId'] as String?;
      final buyerId = data['buyerId'] as String?;
      if (sellerId != uid && buyerId != uid) {
        throw Exception('この依頼を表示する権限がありません');
      }
      return doc;
    });
  },
);

class SellerRequestDetailScreen extends ConsumerStatefulWidget {
  const SellerRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<SellerRequestDetailScreen> createState() =>
      _SellerRequestDetailScreenState();
}

class _SellerRequestDetailScreenState
    extends ConsumerState<SellerRequestDetailScreen> {
  bool _processing = false;
  bool _paying = false;

  Future<void> _updateStatus(String status) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.requestId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('依頼を$statusにしました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDoc = ref.watch(
      sellerRequestDetailProvider(widget.requestId),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '依頼の詳細',
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
      body: asyncDoc.when(
        data: (doc) {
          final data = doc.data() ?? <String, dynamic>{};
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final sellerId = data['sellerId'] as String?;
          final buyerId = data['buyerId'] as String?;
          final isSeller = currentUid != null && sellerId == currentUid;
          final isBuyer = currentUid != null && buyerId == currentUid;
          final counterpartId = currentUid == sellerId ? buyerId : sellerId;
          final serviceTitle = data['serviceTitle'] as String? ?? 'サービス';
          final buyerName = data['buyerName'] as String? ?? '購入者';
          final detail = data['detail'] as String? ?? '';
          final message = data['message'] as String? ?? '';
          final status = data['status'] as String? ?? 'requested';
          final requestType = data['requestType'] as String? ?? 'service';
          final isProfileContract = requestType == 'profileContract';
          final transactionId = data['transactionId'] as String?;
          final createdAt =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final requestedAtLabel =
              DateFormat('yyyy/MM/dd HH:mm').format(createdAt);
          final timeline =
              data['timeline'] as String?; // 文字列にして保存しておく想定

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '依頼者: $buyerName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '依頼日時: $requestedAtLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (timeline != null && timeline.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '希望日時: $timeline',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '依頼内容',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.isEmpty ? '（依頼内容は入力されていません）' : detail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'メッセージ（任意）',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.isEmpty ? '（メッセージはありません）' : message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '現在のステータス: $status',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (isSeller) ...[
                  if (status == 'requested') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _processing ? null : () => _updateStatus('rejected'),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                            ),
                            child: const Text('却下する'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _processing ? null : () => _updateStatus('approved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                            ),
                            child: Text(_processing ? '処理中...' : '承認して進む'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '※ 条件変更の提案や詳細な相談は、チャットから行ってください。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withOpacity(0.9),
                      ),
                    ),
                  ] else if (!isProfileContract &&
                      (status == 'paid' ||
                          status == 'inProgress' ||
                          status == 'completed') &&
                      transactionId != null &&
                      transactionId.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.push('/transactions/$transactionId'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                        ),
                        child: const Text('取引詳細へ'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '※ この依頼から作成された取引の詳細画面に移動します。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (isProfileContract && status == 'approved') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: counterpartId == null
                            ? null
                            : () => _openChat(counterpartId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                        ),
                        child: const Text('メッセージで契約調整する'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '※ この依頼はプロフィール契約です。支払い前にチャットで条件を確定してください。',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ] else if (isBuyer) ...[
                  if (status == 'approved') ...[
                    if (isProfileContract) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _paying ? null : () => _startPayment(data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                ),
                              ),
                              child: Text(_paying ? '処理中...' : '契約して支払いへ進む'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (counterpartId == null || _processing)
                                  ? null
                                  : () => _openChat(counterpartId),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                ),
                              ),
                              child: const Text('チャットで相談'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '※ プロフィール契約の金額で決済を開始します。必要なら先にチャットで条件調整してください。',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _paying ? null : () => _startPayment(data),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                          ),
                          child: Text(_paying ? '処理中...' : '支払いへ進む'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '※ 支払い完了後に取引が開始されます。',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ] else if (status == 'paid' ||
                      status == 'inProgress' ||
                      status == 'completed') ...[
                    if (transactionId != null && transactionId.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              context.push('/transactions/$transactionId'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                          ),
                          child: const Text('取引詳細へ'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '※ この依頼から作成された取引の詳細画面に移動します。',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        '※ この依頼は進行中です。取引詳細は「取引中」ページから確認できます。',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      '※ 出品者が依頼を承認すると、ここから支払いに進めます。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('読み込みに失敗しました: $e')),
      ),
    );
  }

  Future<void> _openChat(String otherId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final chatId =
          await ref.read(chatRepositoryProvider).findOrCreateChat(userId, otherId);
      if (!mounted) return;
      context.push('/chats/$chatId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('チャットを開けませんでした: $e')));
    }
  }
  
  Future<void> _startPayment(Map<String, dynamic> data) async {
    if (_paying) return;
    final requestType = data['requestType'] as String? ?? 'service';
    final isProfileContract = requestType == 'profileContract';
    final serviceId = data['serviceId'] as String?;
    final sellerId = data['sellerId'] as String?;
    if (sellerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('契約情報が不足しています。もう一度お試しください。')),
      );
      return;
    }
    setState(() => _paying = true);
    try {
      int? amount;
      String effectiveServiceId;
      if (isProfileContract) {
        final rawRate = data['offeredHourlyRate'];
        amount = rawRate is num ? rawRate.toInt() : null;
        effectiveServiceId = 'profile_contract_${widget.requestId}';
      } else {
        if (serviceId == null || serviceId.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('サービス情報が不足しています。もう一度お試しください。')),
          );
          return;
        }
        final serviceSnap = await FirebaseFirestore.instance
            .collection('services')
            .doc(serviceId)
            .get();
        final sData = serviceSnap.data();
        if (!serviceSnap.exists || sData == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('サービスが見つかりませんでした')),
          );
          return;
        }
        final rawPrice = sData['price'];
        amount = (rawPrice is num) ? rawPrice.toInt() : null;
        effectiveServiceId = serviceId;
      }
      if (amount == null || amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('契約金額が無効です')),
        );
        return;
      }

      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      final result = await functions
          .httpsCallable('createEscrowPaymentIntent')
          .call(<String, dynamic>{
        'amount': amount,
        'currency': 'jpy',
        'serviceId': effectiveServiceId,
        'sellerId': sellerId,
        'requestId': widget.requestId,
        'requestType': requestType,
        'requestTitle': (data['serviceTitle'] as String?) ?? 'プロフィール契約',
      });
      final resData = result.data as Map<String, dynamic>?;
      final txId = resData?['transactionId'] as String?;
      final clientSecret = resData?['clientSecret'] as String?;
      if (!mounted) return;
      if (txId == null || txId.isEmpty || clientSecret == null || clientSecret.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支払いの準備に失敗しました。もう一度お試しください。')),
        );
        return;
      }

      // Notify seller that buyer started payment from this service request.
      try {
        await functions
            .httpsCallable('sendUserNotification')
            .call(<String, dynamic>{
          'userId': sellerId,
          'title': '新しい購入手続きが開始されました',
          'body': '購入者が支払いを開始しました。決済完了後、サービス提供をお願いします。',
          'type': 'transaction',
          'extraData': {'transactionId': txId},
        });
      } catch (_) {
        // Ignore notification failures.
      }

      // リクエストにも取引IDとステータスを保存しておく
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.requestId)
          .update({
        'status': 'paid',
        'transactionId': txId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      context.go('/transactions/$txId/payment', extra: clientSecret);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('支払いの準備に失敗しました: ${e.message ?? e.code}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払いの準備に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }
}

