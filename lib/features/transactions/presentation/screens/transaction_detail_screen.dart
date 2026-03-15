import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../services/domain/models/service.dart';
import '../../../services/presentation/providers/service_detail_provider.dart';
import '../../domain/models/transaction.dart';
import '../providers/transaction_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.service,
  });

  final String transactionId;
  final Service? service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('取引')),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    if (transactionId == 'new') {
      if (service == null) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _safePop(context),
            ),
            title: const Text('購入'),
          ),
          body: const Center(
            child: Text('サービス情報がありません。\n商品ページから再度お試しください。'),
          ),
        );
      }
      return _PurchaseConfirmScreen(service: service!, userId: user.uid);
    }

    final txAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _safePop(context),
        ),
        title: const Text('取引の詳細'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: txAsync.when(
        data: (tx) => _TransactionDetailContent(transaction: tx, userId: user.uid),
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
}

class _PurchaseConfirmScreen extends ConsumerStatefulWidget {
  const _PurchaseConfirmScreen({required this.service, required this.userId});

  final Service service;
  final String userId;

  @override
  ConsumerState<_PurchaseConfirmScreen> createState() => _PurchaseConfirmScreenState();
}

class _PurchaseConfirmScreenState extends ConsumerState<_PurchaseConfirmScreen> {
  bool _submitting = false;

  Future<void> _confirmPurchase() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final txId = await repo.createPending(
        serviceId: widget.service.id,
        buyerId: widget.userId,
        sellerId: widget.service.ownerId,
        price: widget.service.price,
      );
      if (!mounted) return;
      context.go('/transactions/$txId/payment');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取引の作成に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final durationLabel = s.duration >= 60
        ? (s.duration == 60 ? '1時間' : '${s.duration ~/ 60}時間${s.duration % 60}分')
        : '${s.duration}分';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _safePop(context),
        ),
        title: const Text('購入の確認'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.images.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 160,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: s.images.first,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.primarySoft,
                                  child: const Icon(Icons.broken_image_outlined, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          s.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.location,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '¥${NumberFormat('#,###').format(s.price)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/ $durationLabel',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '支払いについて',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '「購入を確定する」をタップすると取引が作成され、出品者に通知されます。'
                    '支払い方法の選択は次の画面で行えます。（決済連携は準備中です）',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('合計', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      Text(
                        '¥${NumberFormat('#,###').format(s.price)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _confirmPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(_submitting ? '処理中...' : '購入を確定する'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailContent extends ConsumerWidget {
  const _TransactionDetailContent({required this.transaction, required this.userId});

  final TransactionModel transaction;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(transaction.serviceId));
    final tabIndex = _tabIndexForStatus(transaction.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusHeader(status: transaction.status),
          const SizedBox(height: 16),
          _ProgressTabs(currentIndex: tabIndex),
          const SizedBox(height: 20),
          const Text(
            '購入した商品',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          serviceAsync.when(
            data: (service) => _PurchasedItemCard(service: service),
            loading: () => const _PurchasedItemCardPlaceholder(),
            error: (_, __) => const _PurchasedItemCardPlaceholder(),
          ),
          const SizedBox(height: 20),
          _SellerSection(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openChatWithSeller(context, ref),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: const Text('出品者にメッセージ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (transaction.status == TransactionStatus.pending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/transactions/${transaction.id}/payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('支払い方法を選択'),
              ),
            ),
          ],
          if (transaction.status == TransactionStatus.inProgress ||
              transaction.status == TransactionStatus.paid) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmReceipt(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('サービスを受け取りました'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('重要: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(
                    child: Text(
                      'サービスを受け取ったら、必ず受取評価を行ってください。評価完了後、出品者に売上金が支払われます。',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _tabIndexForStatus(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 0;
      case TransactionStatus.paid:
      case TransactionStatus.inProgress:
        return 1;
      case TransactionStatus.completed:
        return 2;
      case TransactionStatus.reviewed:
        return 3;
    }
  }

  Future<void> _openChatWithSeller(BuildContext context, WidgetRef ref) async {
    final chatId = await ref.read(chatRepositoryProvider).findOrCreateChat(userId, transaction.sellerId);
    if (context.mounted) context.push('/chats/$chatId');
  }

  Future<void> _confirmReceipt(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(transactionRepositoryProvider).updateStatus(transaction.id, TransactionStatus.completed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('受取完了しました。評価をお願いします。')),
        );
        context.push('/transactions/${transaction.id}/completed');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _statusText(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, size: 28, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String?) _statusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return ('支払い待ち', '支払い方法を選択して完了してください。');
      case TransactionStatus.paid:
        return ('サービス提供待ち', '出品者がサービスを提供するまでお待ちください。');
      case TransactionStatus.inProgress:
        return ('サービス提供待ち', '出品者がサービスを提供するまでお待ちください。');
      case TransactionStatus.completed:
        return ('完了', '評価を行って取引を完了してください。');
      case TransactionStatus.reviewed:
        return ('レビュー済み', '取引が完了しました。');
    }
  }
}

class _ProgressTabs extends StatelessWidget {
  const _ProgressTabs({required this.currentIndex});

  final int currentIndex;

  static const _labels = ['支払い', '提供中', '完了', '評価'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final isSelected = i == currentIndex;
        return Expanded(
          child: Column(
            children: [
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PurchasedItemCard extends StatelessWidget {
  const _PurchasedItemCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
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
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.primary),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('取引中', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasedItemCardPlaceholder extends StatelessWidget {
  const _PurchasedItemCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SellerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primarySoft,
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'みみちゃん',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  ...List.generate(5, (_) => const Icon(Icons.star, size: 14, color: Color(0xFFFFB300))),
                  const SizedBox(width: 4),
                  Text('(67)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Icon(Icons.verified, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 2),
                  Text('本人確認済', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}


