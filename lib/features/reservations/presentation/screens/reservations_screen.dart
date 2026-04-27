import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// Reservation hub (reference: light canvas, segmented tabs, rich cards).
const Color _kReservationsBg = Color(0xFFF7F7F7);
const Color _kSegmentTrack = Color(0xFFE8E8E8);
const Color _kDetailBoxFill = Color(0xFFF0F0F0);
const Color _kStatusPendingBg = Color(0xFFFFF3E0);
const Color _kStatusPendingFg = Color(0xFFE65100);
const Color _kNewRequestTagBg = Color(0xFFE3F2FD);
const Color _kNewRequestTagFg = Color(0xFF1565C0);
const Color _kApproveBlue = Color(0xFF1E88E5);
const double _kCardRadius = 22;

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  /// 0 = 自分の予定 (buyer), 1 = 受けた予約 (seller)
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final bottomInset = AppSpacing.bottomForFloatingShell(context);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: _kReservationsBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: AppSpacing.listHorizontal,
        title: const Text(
          '予約管理',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _kReservationsBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/notifications'),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        AppIcons.notifications_outlined,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('ログインが必要です'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.listHorizontal,
                    4,
                    AppSpacing.listHorizontal,
                    16,
                  ),
                  child: _ReservationSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                ),
                Expanded(
                  child: _tabIndex == 0
                      ? _MyScheduleList(uid: uid, bottomInset: bottomInset)
                      : _ReceivedList(uid: uid, bottomInset: bottomInset),
                ),
              ],
            ),
    );
  }
}

class _ReservationSegmentedControl extends StatelessWidget {
  const _ReservationSegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kSegmentTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentChip(
              label: '自分の予定',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentChip(
              label: '受けた予約',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyScheduleList extends StatelessWidget {
  const _MyScheduleList({
    required this.uid,
    required this.bottomInset,
  });

  final String uid;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('buyerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '読み込みに失敗しました\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyHint(
            bottomInset: bottomInset,
            message: '予約はまだありません',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.listHorizontal,
            0,
            AppSpacing.listHorizontal,
            bottomInset,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _ReservationCard(
              doc: doc,
              view: _ReservationCardView.asBuyer,
            );
          },
        );
      },
    );
  }
}

class _ReceivedList extends StatelessWidget {
  const _ReceivedList({
    required this.uid,
    required this.bottomInset,
  });

  final String uid;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '読み込みに失敗しました\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyHint(
            bottomInset: bottomInset,
            message: '受けた予約はまだありません',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.listHorizontal,
            0,
            AppSpacing.listHorizontal,
            bottomInset,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _ReservationCard(
              doc: doc,
              view: _ReservationCardView.asSeller,
            );
          },
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.bottomInset,
    required this.message,
  });

  final double bottomInset;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(24, 48, 24, bottomInset),
      children: [
        Icon(
          AppIcons.calendar_today,
          size: 56,
          color: AppColors.textSecondary.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

enum _ReservationCardView { asBuyer, asSeller }

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.doc,
    required this.view,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final _ReservationCardView view;

  static final _yen = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final status = (data['status'] as String?)?.trim().toLowerCase() ?? 'requested';
    final isSeller = view == _ReservationCardView.asSeller;
    final isSellerIncoming = isSeller && status == 'requested';

    if (isSellerIncoming) {
      return _buildSellerIncomingRequestLayout(context, data);
    }

    return _buildDefaultReservationLayout(context, data, status);
  }

  /// 受けた予約・新着（承認待ち）— 新着リクエスト pill、相対時刻、ゲスト、辞退/承認。
  Widget _buildSellerIncomingRequestLayout(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final serviceTitle = (data['serviceTitle'] as String?)?.trim() ?? 'サービス';
    final buyerName = (data['buyerName'] as String?)?.trim() ?? 'ゲスト';
    final categoryRaw = (data['category'] as String?)?.trim();
    final timeline = data['timeline'] as String?;
    final locationSnapshot = data['locationSnapshot'] as String?;
    final counterpartId = data['buyerId'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final timeLabel = _formatScheduleLine(timeline);
    final locationLabel =
        (locationSnapshot != null && locationSnapshot.trim().isNotEmpty)
            ? locationSnapshot.trim()
            : '場所未設定';
    final categoryLine = _categorySubtitle(categoryRaw, serviceTitle);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        onTap: () => context.push('/seller/requests/${doc.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kNewRequestTagBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '新着リクエスト',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kNewRequestTagFg,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _relativeTime(createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CounterpartAvatar(userId: counterpartId),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  buyerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ゲスト',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            categoryLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kDetailBoxFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AppIcons.schedule,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AppIcons.place_outlined,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locationLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _confirmReject(context, doc.id),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: const Color(0xFFE8E8E8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '辞退する',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _kApproveBlue.withValues(alpha: 0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: _kApproveBlue,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => _approveRequest(context, doc.id),
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text(
                                  '承認する',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultReservationLayout(
    BuildContext context,
    Map<String, dynamic> data,
    String status,
  ) {
    final serviceTitle = (data['serviceTitle'] as String?)?.trim() ?? 'サービス';
    final buyerName = (data['buyerName'] as String?)?.trim() ?? '依頼者';
    final sellerName = (data['sellerName'] as String?)?.trim();
    final timeline = data['timeline'] as String?;
    final locationSnapshot = data['locationSnapshot'] as String?;
    final offeredHourlyRate = data['offeredHourlyRate'];

    final isBuyer = view == _ReservationCardView.asBuyer;
    final counterpartId =
        isBuyer ? (data['sellerId'] as String?) : (data['buyerId'] as String?);
    final displayName = isBuyer ? (sellerName ?? '相手') : buyerName;

    final timeLabel = _formatScheduleLine(timeline);
    final locationLabel =
        (locationSnapshot != null && locationSnapshot.trim().isNotEmpty)
            ? locationSnapshot.trim()
            : '場所未設定';

    final priceLabel = _formatPrice(offeredHourlyRate);

    final tag = _statusTag(status);
    final canCancel = status == 'requested';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        onTap: () => context.push('/seller/requests/${doc.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tag,
                    const Spacer(),
                    Text(
                      _relativeTime(createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CounterpartAvatar(userId: counterpartId),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kDetailBoxFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AppIcons.schedule,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AppIcons.place_outlined,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locationLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        priceLabel,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: canCancel
                          ? () => _confirmCancel(context, doc.id)
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: const Color(0xFFE8E8E8),
                        disabledForegroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _categorySubtitle(String? category, String serviceTitle) {
    final base = (category != null && category.isNotEmpty)
        ? category
        : serviceTitle;
    if (base.contains('カフェ') || base.contains('お茶')) {
      return '☕ $base';
    }
    return base;
  }

  static String _relativeTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    var diff = now.difference(t);
    if (diff.isNegative) diff = Duration.zero;
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return DateFormat('M/d', 'ja').format(t);
  }

  static Future<void> _approveRequest(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(docId)
          .update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('承認しました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  static Future<void> _confirmReject(BuildContext context, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('依頼を辞退'),
        content: const Text('このリクエストを辞退しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('閉じる'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('辞退する'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(docId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('辞退しました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  static Widget _statusTag(String status) {
    late final String label;
    Color bg;
    Color fg;
    switch (status) {
      case 'requested':
        label = '承認待ち';
        bg = _kStatusPendingBg;
        fg = _kStatusPendingFg;
        break;
      case 'approved':
        label = '承認済み';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'rejected':
        label = '却下';
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case 'changed':
        label = '条件変更中';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57C00);
        break;
      case 'cancelled':
      case 'canceled':
        label = 'キャンセル';
        bg = const Color(0xFFF5F5F5);
        fg = AppColors.textSecondary;
        break;
      default:
        label = status;
        bg = const Color(0xFFF5F5F5);
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static String _formatScheduleLine(String? timeline) {
    if (timeline == null || timeline.isEmpty) {
      return '日時は未定です';
    }
    try {
      final dt = DateFormat('yyyy/MM/dd HH:mm').parse(timeline.trim());
      final wd = DateFormat.E('ja').format(dt);
      final start = DateFormat('M月d日', 'ja').format(dt);
      final hm = DateFormat('HH:mm').format(dt);
      final end = dt.add(const Duration(hours: 2));
      final hmEnd = DateFormat('HH:mm').format(end);
      return '$start($wd) $hm～$hmEnd';
    } catch (_) {
      return timeline;
    }
  }

  static String _formatPrice(dynamic offeredHourlyRate) {
    if (offeredHourlyRate == null) return '¥—';
    if (offeredHourlyRate is num) {
      return _yen.format(offeredHourlyRate.round());
    }
    return '¥—';
  }

  static Future<void> _confirmCancel(BuildContext context, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('予約をキャンセル'),
        content: const Text('この予約をキャンセルしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('閉じる'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('キャンセルする'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(docId)
          .update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約をキャンセルしました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }
}

class _CounterpartAvatar extends StatelessWidget {
  const _CounterpartAvatar({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    if (userId == null || userId!.isEmpty) {
      return _placeholder(size);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final url = (snap.data?.data()?['photoURL'] as String?)?.trim();
        if (url != null && url.isNotEmpty) {
          return ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(size),
                errorWidget: (_, __, ___) => _placeholder(size),
              ),
            ),
          );
        }
        return _placeholder(size);
      },
    );
  }

  static Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E7EB),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }
}
