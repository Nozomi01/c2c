import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../services/domain/models/service.dart';
import '../../../services/presentation/providers/service_detail_provider.dart';
import '../../domain/models/transaction.dart';
import '../providers/transaction_providers.dart';

class RateTransactionScreen extends ConsumerStatefulWidget {
  const RateTransactionScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<RateTransactionScreen> createState() => _RateTransactionScreenState();
}

class _RateTransactionScreenState extends ConsumerState<RateTransactionScreen> {
  int _rating = 1;
  final _commentController = TextEditingController();

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
          icon: const Icon(AppIcons.arrow_back),
          onPressed: () => _safePop(context),
        ),
        title: const Text('取引相手を評価'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: txAsync.when(
        data: (tx) => _Content(
          transaction: tx,
          rating: _rating,
          onRatingChanged: (v) => setState(() => _rating = v),
          commentController: _commentController,
          onSubmit: _submit,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
    try {
      await ref.read(transactionRepositoryProvider).setReview(
            widget.transactionId,
            _rating,
            comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('評価を送信しました')),
      );
      _safePop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信に失敗しました: $e')),
        );
      }
    }
  }
}

const _ratingLabels = ['悪い', '普通', '良い', 'とても良い', '最高'];

String _ratingLabel(int rating) =>
    _ratingLabels[(rating.clamp(1, 5) - 1)];

class _Content extends ConsumerWidget {
  const _Content({
    required this.transaction,
    required this.rating,
    required this.onRatingChanged,
    required this.commentController,
    required this.onSubmit,
  });

  final TransactionModel transaction;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController commentController;
  final VoidCallback onSubmit;

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
            data: (service) => _ProductCard(service: service),
            loading: () => const _ProductCardPlaceholder(),
            error: (_, __) => const _ProductCardPlaceholder(),
          ),
          const SizedBox(height: 24),
          // 取引はいかがでしたか?
          const Text(
            '取引はいかがでしたか?',
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
                  selected ? AppIcons.star : AppIcons.star_border,
                  size: 40,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            _ratingLabel(rating),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // コメント (任意)
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
              hintText: '取引の感想をお聞かせください',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          // Blue info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
            child: const Text(
              '評価は取引完了後に公開されます。相手の評価も確認できるようになります。',
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
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
              child: const Text('評価を送信'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xs),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl == null
                  ? Container(
                      color: AppColors.primarySoft,
                      child: const Icon(AppIcons.image, color: AppColors.primary),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(AppIcons.broken_image_outlined, color: AppColors.primary),
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
                const SizedBox(height: 4),
                const Text(
                  '出品者: 出品者',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCardPlaceholder extends StatelessWidget {
  const _ProductCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
