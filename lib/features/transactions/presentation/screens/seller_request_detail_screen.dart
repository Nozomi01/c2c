import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';

final sellerRequestDetailProvider =
    FutureProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
  (ref, requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('ログインが必要です');
    }
    final doc = await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(requestId)
        .get();
    if (!doc.exists) {
      throw Exception('依頼が見つかりませんでした');
    }
    if (doc.data()?['sellerId'] != user.uid) {
      throw Exception('この依頼を表示する権限がありません');
    }
    return doc;
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
          icon: const Icon(Icons.chevron_left),
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
          final serviceTitle = data['serviceTitle'] as String? ?? 'サービス';
          final buyerName = data['buyerName'] as String? ?? '購入者';
          final detail = data['detail'] as String? ?? '';
          final message = data['message'] as String? ?? '';
          final status = data['status'] as String? ?? 'requested';
          final createdAt =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final requestedAtLabel =
              DateFormat('yyyy/MM/dd HH:mm').format(createdAt);
          final timeline =
              data['timeline'] as String?; // 文字列にして保存しておく想定

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
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
                            borderRadius: BorderRadius.circular(10),
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
                            borderRadius: BorderRadius.circular(10),
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
}

