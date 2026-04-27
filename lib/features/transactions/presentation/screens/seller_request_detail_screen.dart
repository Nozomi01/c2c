import 'package:cached_network_image/cached_network_image.dart';
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

const Color _kDetailPageBg = Color(0xFFF7F7F7);
const double _kDetailCardRadius = 20;
const Color _kStatusConfirmedBg = Color(0xFFE8F5E9);
const Color _kStatusConfirmedFg = Color(0xFF2E7D32);

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
      backgroundColor: _kDetailPageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '予約の詳細',
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
          final detail = data['detail'] as String? ?? '';
          final message = data['message'] as String? ?? '';
          final status = data['status'] as String? ?? 'requested';
          final requestType = data['requestType'] as String? ?? 'service';
          final isProfileContract = requestType == 'profileContract';
          final transactionId = data['transactionId'] as String?;
          final timeline = data['timeline'] as String?;
          final locationSnapshot = data['locationSnapshot'] as String?;
          final category = (data['category'] as String?)?.trim();

          final bottomPad = MediaQuery.paddingOf(context).bottom;
          final showBottomBar =
              counterpartId != null && !(isSeller && status == 'requested');

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.listHorizontal,
                    16,
                    AppSpacing.listHorizontal,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _statusPriceCard(
                        status: status,
                        requestId: widget.requestId,
                        data: data,
                      ),
                      const SizedBox(height: 6),
                      if (counterpartId != null)
                        _profileCard(
                          context: context,
                          userId: counterpartId,
                        ),
                      if (counterpartId != null)
                        const SizedBox(height: 16),
                      _detailsCard(
                        category: category,
                        serviceTitle: serviceTitle,
                        timeline: timeline,
                        locationSnapshot: locationSnapshot,
                        detail: detail,
                        message: message,
                      ),
                      const SizedBox(height: 16),
                      if (isSeller && status == 'requested') ...[
                        _whiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _processing
                                          ? null
                                          : () => _updateStatus('rejected'),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        foregroundColor: AppColors.textPrimary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: const Text('却下する'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _processing
                                          ? null
                                          : () => _updateStatus('approved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _processing ? '処理中...' : '承認して進む',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '※ 条件変更の提案や詳細な相談は、チャットから行ってください。',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isSeller) ...[
                        if (!isProfileContract &&
                            (status == 'paid' ||
                                status == 'inProgress' ||
                                status == 'completed') &&
                            transactionId != null &&
                            transactionId.isNotEmpty) ...[
                          _actionCard(
                            child: ElevatedButton(
                              onPressed: () => context.push(
                                '/transactions/$transactionId',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
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
                          _actionCard(
                            child: ElevatedButton(
                              onPressed: counterpartId == null
                                  ? null
                                  : () => _openChat(counterpartId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('メッセージで契約調整する'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '※ この依頼はプロフィール契約です。支払い前にチャットで条件を確定してください。',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ] else if (isBuyer) ...[
                        if (status == 'approved') ...[
                          if (isProfileContract) ...[
                            _whiteCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _paying
                                          ? null
                                          : () => _startPayment(data),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _paying
                                            ? '処理中...'
                                            : '契約して支払いへ進む',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: (counterpartId == null ||
                                              _processing)
                                          ? null
                                          : () => _openChat(counterpartId),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.textPrimary,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: const Text('チャットで相談'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '※ プロフィール契約の金額で決済を開始します。必要なら先にチャットで条件調整してください。',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ] else ...[
                            _actionCard(
                              child: ElevatedButton(
                                onPressed: _paying
                                    ? null
                                    : () => _startPayment(data),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _paying ? '処理中...' : '支払いへ進む',
                                ),
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
                          if (transactionId != null &&
                              transactionId.isNotEmpty) ...[
                            _actionCard(
                              child: ElevatedButton(
                                onPressed: () => context.push(
                                  '/transactions/$transactionId',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                      SizedBox(height: showBottomBar ? 8 : bottomPad + 24),
                    ],
                  ),
                ),
              ),
              if (showBottomBar)
                _bottomActionBar(
                  bottomInset: bottomPad,
                  counterpartId: counterpartId,
                  status: status,
                  isSeller: isSeller,
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('読み込みに失敗しました: $e')),
      ),
    );
  }

  static final _yen = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  String _reservationNumber(String id) {
    final n = id.hashCode.abs() % 90000 + 10000;
    return '#$n';
  }

  Widget _statusPriceCard({
    required String status,
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _statusBadgeForDetail(status)),
          const SizedBox(height: 6),
          Text(
            '予約番号 ${_reservationNumber(requestId)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _priceHeadline(data),
        ],
      ),
    );
  }

  Widget _priceHeadline(Map<String, dynamic> data) {
    final rt = data['requestType'] as String? ?? 'service';
    if (rt == 'profileContract') {
      final r = data['offeredHourlyRate'];
      final v = r is num ? r.toInt() : null;
      return Text(
        v == null ? '¥—' : _yen.format(v),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      );
    }
    final sid = data['serviceId'] as String?;
    if (sid == null || sid.isEmpty) {
      return const Text(
        '¥—',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .doc(sid)
          .snapshots(),
      builder: (context, snap) {
        final p = snap.data?.data()?['price'];
        final v = p is num ? p.toInt() : null;
        return Text(
          v == null ? '¥—' : _yen.format(v),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        );
      },
    );
  }

  Widget _statusBadgeForDetail(String status) {
    switch (status) {
      case 'approved':
      case 'paid':
      case 'inProgress':
      case 'completed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kStatusConfirmedBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 18,
                color: _kStatusConfirmedFg,
              ),
              const SizedBox(width: 6),
              const Text(
                '予約確定',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kStatusConfirmedFg,
                ),
              ),
            ],
          ),
        );
      case 'requested':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '承認待ち',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE65100),
            ),
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '却下',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC62828),
            ),
          ),
        );
      case 'cancelled':
      case 'canceled':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'キャンセル',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kStatusConfirmedBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kStatusConfirmedFg,
            ),
          ),
        );
    }
  }

  Widget _profileCard({
    required BuildContext context,
    required String userId,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final name = (d?['displayName'] as String?)?.trim();
        final display = (name != null && name.isNotEmpty) ? name : 'ユーザー';
        final photo = (d?['photoURL'] as String?)?.trim();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_kDetailCardRadius),
            onTap: () => context.push('/people/$userId'),
            child: _whiteCard(
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: photo != null && photo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photo,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _avatarPlaceholder(),
                              errorWidget: (_, __, ___) => _avatarPlaceholder(),
                            )
                          : _avatarPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'プロフィールを見る',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.chevron_right,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Icon(
        Icons.person_rounded,
        size: 30,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _detailsCard({
    required String? category,
    required String serviceTitle,
    required String? timeline,
    required String? locationSnapshot,
    required String detail,
    required String message,
  }) {
    final wishLine = (category != null && category.isNotEmpty)
        ? category
        : serviceTitle;
    final timeLine = _formatScheduleLine(timeline);
    final locLine = _locationDisplayLine(locationSnapshot);
    final online = _locationLooksOnline(locationSnapshot);

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailSection(
            label: '希望内容',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.chat_bubble_outline,
                  size: 20,
                  color: const Color(0xFF1976D2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wishLine,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (detail.isNotEmpty) ...[
            const Divider(height: 28),
            _detailSection(
              label: '依頼詳細',
              child: Text(
                detail,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const Divider(height: 28),
          _detailSection(
            label: '日時',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.schedule,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeLine,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 28),
          _detailSection(
            label: '場所・エリア',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  online ? Icons.desktop_windows_outlined : AppIcons.place_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locLine,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 28),
          _detailSection(
            label: 'メッセージ',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.isEmpty
                    ? '（メッセージはありません）'
                    : message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: message.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  bool _locationLooksOnline(String? s) {
    if (s == null || s.isEmpty) return false;
    final t = s.toLowerCase();
    return t.contains('online') ||
        t.contains('オンライン') ||
        t.contains('zoom');
  }

  String _locationDisplayLine(String? locationSnapshot) {
    if (locationSnapshot != null && locationSnapshot.trim().isNotEmpty) {
      return locationSnapshot.trim();
    }
    return '—';
  }

  String _formatScheduleLine(String? timeline) {
    if (timeline == null || timeline.isEmpty) {
      return '日時は未定です';
    }
    try {
      final dt = DateFormat('yyyy/MM/dd HH:mm').parse(timeline.trim());
      final wd = DateFormat.E('ja').format(dt);
      final start = DateFormat('M月d日', 'ja').format(dt);
      final hm = DateFormat('HH:mm').format(dt);
      final end = dt.add(const Duration(hours: 1));
      final hmEnd = DateFormat('HH:mm').format(end);
      return '$start($wd) $hm～$hmEnd';
    } catch (_) {
      return timeline;
    }
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kDetailCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionCard({required Widget child}) {
    return _whiteCard(child: child);
  }

  Widget _bottomActionBar({
    required double bottomInset,
    required String counterpartId,
    required String status,
    required bool isSeller,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextButton(
              onPressed: status == 'requested'
                  ? () => _onCancelRequest(isSeller: isSeller)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: const Color(0xFFE8E8E8),
                disabledForegroundColor: AppColors.textSecondary,
                disabledBackgroundColor: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _openChat(counterpartId),
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'メッセージを送る',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    );
  }

  Future<void> _onCancelRequest({required bool isSeller}) async {
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
    if (ok != true || !mounted) return;
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.requestId)
          .update({
        'status': isSeller ? 'rejected' : 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('キャンセルしました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
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
          .call<Map<String, dynamic>>(<String, dynamic>{
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
            .call<Map<String, dynamic>>(<String, dynamic>{
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

      if (!mounted) return;
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

