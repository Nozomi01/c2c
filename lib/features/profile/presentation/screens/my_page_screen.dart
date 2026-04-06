import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../providers/profile_mode_provider.dart';

// --- Design tokens (profile reference) ---
const Color _kPageBg = Color(0xFFF5F5F7);
const double _kCardCorner = 24;
const Color _kEditPillBg = Color(0xFFE8EAF6);
const Color _kEditPillFg = Color(0xFF2563EB);
const Color _kBadgeRedBg = Color(0xFFFFF0F0);
const Color _kBadgeRedFg = Color(0xFFFF5252);

Widget _avatarPlaceholder(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFE8EAED),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Icon(
      AppIcons.person_outline,
      size: size * 0.45,
      color: const Color(0xFF9AA0A6),
    ),
  );
}

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'ゲスト';
    final photoUrl = user?.photoURL;
    final uid = user?.uid;
    final mode = ref.watch(profileModeProvider);
    final bottomSafe = AppSpacing.bottomForFloatingShell(context);

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.chevron_left),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'マイページ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.listHorizontal,
          AppSpacing.sm,
          AppSpacing.listHorizontal,
          bottomSafe,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeaderBlock(
              uid: uid,
              displayName: displayName,
              photoUrl: photoUrl,
            ),
            if (mode == ProfileMode.seller) ...[
              const SizedBox(height: 20),
              _TotalEarningCard(uid: uid),
            ],
            const SizedBox(height: 20),
            if (mode == ProfileMode.buyer)
              _BuyerGroupedMenus(uid: uid)
            else
              _SellerGroupedMenus(uid: uid),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderBlock extends StatelessWidget {
  const _ProfileHeaderBlock({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
  });

  final String? uid;
  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final dbName = (data['displayName'] as String?)?.trim();
        final effectiveName = (dbName == null || dbName.isEmpty) ? displayName : dbName;
        final dbPhoto = (data['photoURL'] as String?)?.trim();
        final effectivePhoto = (dbPhoto == null || dbPhoto.isEmpty) ? photoUrl : dbPhoto;

        const avatarSize = 72.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipOval(
                  child: effectivePhoto != null && effectivePhoto.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: effectivePhoto,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _avatarPlaceholder(avatarSize),
                        )
                      : _avatarPlaceholder(avatarSize),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    effectiveName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => context.push('/settings/profile'),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kEditPillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'アカウントを編集する',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kEditPillFg,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.chevron_right,
                      size: 14,
                      color: _kEditPillFg,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TotalEarningCard extends StatelessWidget {
  const _TotalEarningCard({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        int balance = 0;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          final raw = snapshot.data!.data()!['walletBalance'];
          if (raw is num) balance = raw.toInt();
        }
        final formatted = '¥${NumberFormat('#,###').format(balance)}';

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCardCorner),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1B4B),
                Color(0xFF172554),
                Color(0xFF0F172A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL EARNING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatted,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: uid == null ? null : () => context.push('/mypage/withdraw'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '振込申請',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardCorner),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.trailing,
    this.showDividerBelow = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    AppIcons.chevron_right,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.65),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDividerBelow)
          Padding(
            padding: const EdgeInsets.only(left: 76),
            child: Divider(height: 1, thickness: 1, color: AppColors.border.withValues(alpha: 0.65)),
          ),
      ],
    );
  }
}

Widget _trailingGray(String text) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary.withValues(alpha: 0.9),
    ),
  );
}

Widget _badgeNotSubmitted() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _kBadgeRedBg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      '未提出',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _kBadgeRedFg,
      ),
    ),
  );
}

class _SellerGroupedMenus extends StatelessWidget {
  const _SellerGroupedMenus({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return _guestMenuCards(context);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final reviewCountRaw = data['reviewCount'];
        final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
        final verifiedRaw = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];
        final verified = verifiedRaw is bool ? verifiedRaw : false;
        final user = FirebaseAuth.instance.currentUser;
        final snsLinked = user != null && user.providerData.length > 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuCard(
              children: [
                _MenuRow(
                  icon: Icons.manage_accounts_rounded,
                  iconBg: const Color(0xFFF3F4F6),
                  iconColor: const Color(0xFF64748B),
                  title: 'プロフィール・出品設定',
                  onTap: () => context.push('/settings/profile'),
                ),
                _MenuRow(
                  icon: AppIcons.star,
                  iconBg: const Color(0xFFFFFBEB),
                  iconColor: const Color(0xFFF59E0B),
                  title: '評価・レビュー',
                  trailing: _trailingGray('$reviewCount件'),
                  onTap: () => context.push('/people/$uid'),
                  showDividerBelow: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: AppIcons.verified_user_outlined,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF10B981),
                  title: '本人確認 (eKYC)',
                  trailing: verified ? _trailingGray('確認済') : _badgeNotSubmitted(),
                  onTap: () => context.push('/settings/identity'),
                ),
                _MenuRow(
                  icon: AppIcons.link,
                  iconBg: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'SNS連携設定',
                  trailing: _trailingGray(snsLinked ? '連携済' : '未設定'),
                  onTap: () => context.push('/settings/account'),
                  showDividerBelow: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: AppIcons.favorite,
                  iconBg: const Color(0xFFFDF2F8),
                  iconColor: const Color(0xFFE11D48),
                  title: 'お気に入りリスト',
                  onTap: () => context.push('/mypage/likes'),
                ),
                _MenuRow(
                  icon: AppIcons.account_balance_wallet_outlined,
                  iconBg: const Color(0xFFF3F4F6),
                  iconColor: const Color(0xFF6B7280),
                  title: 'お支払い・売上管理',
                  onTap: () => context.push('/mypage/transactions'),
                ),
                _MenuRow(
                  icon: AppIcons.help_outline,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  title: 'ヘルプ・お問い合わせ',
                  onTap: () => context.push('/help'),
                  showDividerBelow: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: AppIcons.grid_view_outlined,
                  iconBg: const Color(0xFFF0FDFA),
                  iconColor: const Color(0xFF0D9488),
                  title: '出品一覧',
                  onTap: () => context.push('/mypage/listings'),
                ),
                _MenuRow(
                  icon: AppIcons.account_balance_wallet,
                  iconBg: const Color(0xFFEEF2FF),
                  iconColor: const Color(0xFF4F46E5),
                  title: 'Stripeアカウント連携',
                  onTap: () => context.push('/mypage/stripe'),
                ),
                _MenuRow(
                  icon: AppIcons.notifications_outlined,
                  iconBg: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                  title: '通知設定',
                  onTap: () => context.push('/settings/notifications'),
                  showDividerBelow: false,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Widget _guestMenuCards(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MenuCard(
        children: [
          _MenuRow(
            icon: Icons.manage_accounts_rounded,
            iconBg: const Color(0xFFF3F4F6),
            iconColor: const Color(0xFF64748B),
            title: 'プロフィール・出品設定',
            onTap: () => context.push('/settings/profile'),
            showDividerBelow: false,
          ),
        ],
      ),
    ],
  );
}

class _BuyerGroupedMenus extends StatelessWidget {
  const _BuyerGroupedMenus({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return _guestMenuCards(context);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final reviewCountRaw = data['reviewCount'];
        final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
        final verifiedRaw = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];
        final verified = verifiedRaw is bool ? verifiedRaw : false;
        final user = FirebaseAuth.instance.currentUser;
        final snsLinked = user != null && user.providerData.length > 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuCard(
              children: [
                _MenuRow(
                  icon: Icons.manage_accounts_rounded,
                  iconBg: const Color(0xFFF3F4F6),
                  iconColor: const Color(0xFF64748B),
                  title: 'プロフィール設定',
                  onTap: () => context.push('/settings/profile'),
                ),
                _MenuRow(
                  icon: AppIcons.star,
                  iconBg: const Color(0xFFFFFBEB),
                  iconColor: const Color(0xFFF59E0B),
                  title: '評価・レビュー',
                  trailing: _trailingGray('$reviewCount件'),
                  onTap: () => context.push('/people/$uid'),
                  showDividerBelow: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: AppIcons.verified_user_outlined,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF10B981),
                  title: '本人確認 (eKYC)',
                  trailing: verified ? _trailingGray('確認済') : _badgeNotSubmitted(),
                  onTap: () => context.push('/settings/identity'),
                ),
                _MenuRow(
                  icon: AppIcons.link,
                  iconBg: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'SNS連携設定',
                  trailing: _trailingGray(snsLinked ? '連携済' : '未設定'),
                  onTap: () => context.push('/settings/account'),
                  showDividerBelow: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: AppIcons.favorite,
                  iconBg: const Color(0xFFFDF2F8),
                  iconColor: const Color(0xFFE11D48),
                  title: 'お気に入りリスト',
                  onTap: () => context.push('/mypage/likes'),
                ),
                _MenuRow(
                  icon: AppIcons.settings,
                  iconBg: const Color(0xFFF3F4F6),
                  iconColor: const Color(0xFF6B7280),
                  title: 'アカウント設定',
                  onTap: () => context.push('/settings/account'),
                ),
                _MenuRow(
                  icon: AppIcons.notifications_outlined,
                  iconBg: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                  title: '通知設定',
                  onTap: () => context.push('/settings/notifications'),
                ),
                _MenuRow(
                  icon: AppIcons.help_outline,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  title: 'ヘルプ・お問い合わせ',
                  onTap: () => context.push('/help'),
                  showDividerBelow: false,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
