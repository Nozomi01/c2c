import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../services/domain/models/service.dart';
import '../../../services/presentation/providers/service_detail_provider.dart';
import '../../domain/models/transaction.dart';
import '../providers/transaction_providers.dart';

class RateBuyerScreen extends ConsumerStatefulWidget {
  const RateBuyerScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<RateBuyerScreen> createState() => _RateBuyerScreenState();
}

class _RateBuyerScreenState extends ConsumerState<RateBuyerScreen> {
  int _rating = 1;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _safePop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionDetailProvider(widget.transactionId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _safePop(context),
        ),
        title: const Text('購入者を評価'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: txAsync.when(
        data: (tx) => _BuyerRateContent(
          transaction: tx,
          rating: _rating,
          onRatingChanged: (v) => setState(() => _rating = v),
          commentController: _commentController,
          onSubmit: _submit,
          submitting: _submitting,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('読み込みに失敗しました: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _safePop(context),
                  child: const Text('戻る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final comment = _commentController.text.trim();
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transactionId)
          .update({
        'buyerRating': _rating,
        'buyerReviewComment': comment.isEmpty ? null : comment,
        'buyerReviewedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入者への評価を送信しました')),
      );
      _safePop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

const _buyerRatingLabels = ['悪い', '普通', '良い', 'とても良い', '最高'];

String _buyerRatingLabel(int rating) =>
    _buyerRatingLabels[(rating.clamp(1, 5) - 1)];

class _BuyerRateContent extends ConsumerWidget {
  const _BuyerRateContent({
    required this.transaction,
    required this.rating,
    required this.onRatingChanged,
    required this.commentController,
    required this.onSubmit,
    required this.submitting,
  });

  final TransactionModel transaction;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController commentController;
  final VoidCallback onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(transaction.serviceId));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Product details
          serviceAsync.when(
            data: (service) => _BuyerProductCard(service: service),
            loading: () => const _BuyerProductCardPlaceholder(),
            error: (_, __) => const _BuyerProductCardPlaceholder(),
          ),
          const SizedBox(height: 24),
          const Text(
            '購入者との取引はいかがでしたか？',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final value = i + 1;
              final selected = value <= rating;
              return IconButton(
                onPressed: () => onRatingChanged(value),
                icon: Icon(
                  selected ? Icons.star : Icons.star_border,
                  size: 40,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            _buyerRatingLabel(rating),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'コメント (任意)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '購入者の対応やコミュニケーションについて教えてください',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'この評価は、今後の取引の参考として購入者のプロフィールに反映されます。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1976D2),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(submitting ? '送信中...' : '評価を送信'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BuyerProductCard extends StatelessWidget {
  const _BuyerProductCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl == null
                  ? Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.image, color: AppColors.primary),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.primary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${NumberFormat('#,###').format(service.price)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyerProductCardPlaceholder extends StatelessWidget {
  const _BuyerProductCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

