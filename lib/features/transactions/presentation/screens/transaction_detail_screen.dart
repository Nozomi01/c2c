import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_links.dart';
import '../../../../core/widgets/share_link_bottom_sheet.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
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
              icon: const Icon(AppIcons.arrow_back),
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

    return txAsync.when(
      data: (tx) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.arrow_back),
            onPressed: () => _safePop(context),
          ),
          title: const Text('取引の詳細'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          actions: [
            IconButton(
              icon: const Icon(AppIcons.share_outlined),
              tooltip: 'リンクを共有',
              onPressed: () => _shareTransactionLink(context, tx.id),
            ),
          ],
        ),
        body: _TransactionDetailContent(transaction: tx, userId: user.uid),
      ),
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.arrow_back),
            onPressed: () => _safePop(context),
          ),
          title: const Text('取引の詳細'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.arrow_back),
            onPressed: () => _safePop(context),
          ),
          title: const Text('取引の詳細'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(
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
}

Future<void> _shareTransactionLink(
  BuildContext context,
  String transactionId,
) async {
  final url = AppLinks.transactionShareUrl(transactionId);
  final shareMessage = 'Wanty 取引の詳細\n$url';
  await showShareLinkBottomSheet(
    context,
    url: url,
    shareMessage: shareMessage,
    emailSubject: 'Wanty 取引',
  );
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
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      final result = await functions.httpsCallable('createEscrowPaymentIntent').call({
        'amount': widget.service.price,
        'currency': 'jpy',
        'serviceId': widget.service.id,
        'sellerId': widget.service.ownerId,
      });
      final data = result.data as Map<String, dynamic>?;
      final txId = data?['transactionId'] as String?;
      final clientSecret = data?['clientSecret'] as String?;
      if (!mounted) return;
      if (txId == null || txId.isEmpty || clientSecret == null || clientSecret.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支払いの準備に失敗しました。もう一度お試しください。')),
        );
        return;
      }

      // Notify seller that a buyer started payment (transaction created).
      try {
        await functions.httpsCallable('sendUserNotification').call({
          'userId': widget.service.ownerId,
          'title': '新しい購入が作成されました',
          'body': 'お支払い手続きが開始されました。完了後、サービス提供をご対応ください。',
          'type': 'transaction',
          'extraData': {'transactionId': txId},
        });
      } catch (_) {
        // Notification failure should not block purchase flow.
      }

      context.go('/transactions/$txId/payment', extra: clientSecret);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取引の作成に失敗しました: ${e.message ?? e.code}')),
      );
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
          icon: const Icon(AppIcons.close),
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
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.images.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.xs),
                            child: SizedBox(
                              height: 160,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: s.images.first,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.primarySoft,
                                  child: const Icon(AppIcons.broken_image_outlined, color: AppColors.primary),
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
                    '次の画面でクレジットカード決済を行い、売上金はエスクローで安全に保管されます。',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(AppSpacing.listHorizontal, 12, AppSpacing.listHorizontal, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
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
                          borderRadius: BorderRadius.circular(AppRadii.sm),
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
    final isProfileContract = transaction.serviceId.startsWith('profile_contract_');
    final serviceAsync = isProfileContract
        ? AsyncValue<Service>.data(_virtualServiceFromTransaction(transaction))
        : ref.watch(serviceDetailProvider(transaction.serviceId));
    final tabIndex = _tabIndexForStatus(transaction.status);
    final isBuyer = userId == transaction.buyerId;
    final isSeller = userId == transaction.sellerId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
            data: (service) => _PurchasedItemCard(
              service: service,
              userId: userId,
              isProfileContract: isProfileContract,
            ),
            loading: () => const _PurchasedItemCardPlaceholder(),
            error: (_, __) => const _PurchasedItemCardPlaceholder(),
          ),
          const SizedBox(height: 20),
          _CounterpartySection(
            currentUserId: userId,
            buyerId: transaction.buyerId,
            sellerId: transaction.sellerId,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openChatWithSeller(context, ref),
            icon: const Icon(AppIcons.chat_bubble_outline, size: 20),
            label: const Text('取引相手にメッセージ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
          // 支払い待ち: 購入者のみ決済へ進める
          if (transaction.status == TransactionStatus.pending && isBuyer) ...[
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
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: const Text('支払い方法を選択'),
              ),
            ),
          ],
          // 支払い済み〜提供中のアクション
          if (transaction.status == TransactionStatus.paid && isSeller) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(transactionRepositoryProvider)
                      .updateStatus(transaction.id, TransactionStatus.inProgress);

                  // Notify buyer that seller started service.
                  try {
                    final functions =
                        FirebaseFunctions.instanceFor(region: 'asia-northeast1');
                    await functions.httpsCallable('sendUserNotification').call({
                      'userId': transaction.buyerId,
                      'title': 'サービス提供が開始されました',
                      'body': '出品者がサービス提供を開始しました。',
                      'type': 'transaction',
                      'extraData': {'transactionId': transaction.id},
                    });
                  } catch (_) {
                    // Ignore notification errors.
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: const Text('サービスを提供しました'),
              ),
            ),
          ],
          if (transaction.status == TransactionStatus.inProgress && isBuyer) ...[
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
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: const Text('サービスを受け取りました'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/transactions/${transaction.id}/issues'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: const Text('修正依頼・問題を報告する'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadii.sm),
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
    final otherId = userId == transaction.sellerId ? transaction.buyerId : transaction.sellerId;
    final chatId =
        await ref.read(chatRepositoryProvider).findOrCreateChat(userId, otherId);
    if (context.mounted) context.push('/chats/$chatId');
  }

  Future<void> _confirmReceipt(BuildContext context, WidgetRef ref) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      await functions.httpsCallable('releaseEscrow').call({
        'transactionId': transaction.id,
      });

      if (context.mounted) {
        // Notify seller that buyer confirmed receipt (transaction completed).
        try {
          await functions.httpsCallable('sendUserNotification').call({
            'userId': transaction.sellerId,
            'title': '取引が完了しました',
            'body': '購入者が受取を完了しました。',
            'type': 'transaction',
            'extraData': {'transactionId': transaction.id},
          });
        } catch (_) {
          // ignore notification errors
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('受取完了しました。評価をお願いします。')),
        );
        context.push('/transactions/${transaction.id}/completed');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払いの確定に失敗しました: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
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
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.person_outline, size: 28, color: AppColors.primary),
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
                  borderRadius: BorderRadius.circular(AppRadii.xxs),
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
  const _PurchasedItemCard({
    required this.service,
    required this.userId,
    required this.isProfileContract,
  });

  final Service service;
  final String userId;
  final bool isProfileContract;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xs),
            child: SizedBox(
              width: 80,
              height: 80,
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
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Text('取引中', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          if (!isProfileContract) ...[
            const SizedBox(width: 8),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
              builder: (context, userSnap) {
                final data = userSnap.data?.data() ?? <String, dynamic>{};
                final raw = data['likedServiceIds'];
                final likedIds =
                    raw is List ? raw.whereType<String>().toSet() : <String>{};
                final isLiked = likedIds.contains(service.id);

                return IconButton(
                  tooltip: isLiked ? 'いいねを外す' : 'いいねする',
                  icon: Icon(
                    isLiked ? AppIcons.favorite : AppIcons.favorite_border,
                    size: 22,
                    color: isLiked ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .set(
                      {
                        'likedServiceIds': isLiked
                            ? FieldValue.arrayRemove([service.id])
                            : FieldValue.arrayUnion([service.id]),
                      },
                      SetOptions(merge: true),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

Service _virtualServiceFromTransaction(TransactionModel tx) {
  return Service(
    id: tx.serviceId,
    ownerId: tx.sellerId,
    title: 'プロフィール契約',
    description: 'プロフィールベースの契約取引',
    category: 'プロフィール契約',
    price: tx.price,
    duration: 60,
    location: tx.meetingLocation ?? 'オンライン / 相談',
    onlineAvailable: true,
    offlineAvailable: true,
    createdAt: tx.createdAt,
  );
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
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _CounterpartySection extends StatelessWidget {
  const _CounterpartySection({
    required this.currentUserId,
    required this.buyerId,
    required this.sellerId,
  });

  final String currentUserId;
  final String buyerId;
  final String sellerId;

  @override
  Widget build(BuildContext context) {
    final otherId = currentUserId == sellerId ? buyerId : sellerId;
    final otherIsBuyer = otherId == buyerId;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primarySoft,
          child: const Icon(AppIcons.person, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(otherId).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? <String, dynamic>{};
              final name = (data['displayName'] as String?)?.trim();
              final email = (data['email'] as String?)?.trim();
              final emailPrefix =
                  email != null && email.isNotEmpty && email.contains('@')
                      ? email.split('@').first
                      : null;
              final fallback = otherIsBuyer ? '購入者' : '出品者';
              final displayName =
                  (name == null || name.isEmpty) ? (emailPrefix ?? fallback) : name;
              final ratingRaw = data['rating'];
              final reviewCountRaw = data['reviewCount'];
              final verifiedRaw = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];

              final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;
              final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
              final verified = verifiedRaw is bool ? verifiedRaw : false;

              final r = (rating.isFinite ? rating : 0.0).clamp(0.0, 5.0);
              final filled = r.floor().clamp(0, 5);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final isFilled = i < filled;
                        return Icon(
                          isFilled ? AppIcons.star : AppIcons.star_border,
                          size: 14,
                          color: const Color(0xFFFFB300),
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        reviewCount > 0 ? '(${reviewCount.toString()})' : '(0)',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 8),
                        Icon(AppIcons.verified, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 2),
                        Text('本人確認済', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ],
                  ),
                ],
              );
            },
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


