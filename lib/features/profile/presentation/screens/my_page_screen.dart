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

Widget _avatarPlaceholder(String displayName, double size) {
  return Container(
    width: size,
    height: size,
    color: AppColors.primarySoft,
    alignment: Alignment.center,
    child: Text(
      displayName.isNotEmpty ? displayName[0] : '?',
      style: TextStyle(
        fontSize: size * 0.375,
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
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

    return Scaffold(
      backgroundColor: Colors.white,
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
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileHeaderBlock(
              uid: uid,
              displayName: displayName,
              photoUrl: photoUrl,
            ),
            if (mode == ProfileMode.seller) ...[
              const SizedBox(height: 24),
              _BalanceBlock(uid: uid),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),
            if (mode == ProfileMode.buyer)
              _BuyerMenuList()
            else
              _SellerMenuList(),
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

        final ratingRaw = data['rating'];
        final reviewCountRaw = data['reviewCount'];
        final verifiedRaw = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];
        final bio = (data['bio'] as String?)?.trim() ?? '';
        final hourlyRateRaw = data['hourlyRate'];
        final hourlyRate = hourlyRateRaw is num ? hourlyRateRaw.toInt() : null;

        final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;
        final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
        final verified = verifiedRaw is bool ? verifiedRaw : false;

        final r = (rating.isFinite ? rating : 0.0).clamp(0.0, 5.0);
        final full = r.floor().clamp(0, 5);
        final hasHalf = (r - full) >= 0.5 && full < 5;

        return InkWell(
          onTap: () => context.push('/settings/profile'),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                ClipOval(
                  child: effectivePhoto != null && effectivePhoto.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: effectivePhoto,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _avatarPlaceholder(effectiveName, 64),
                        )
                      : SizedBox(
                          width: 64,
                          height: 64,
                          child: _avatarPlaceholder(effectiveName, 64),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            effectiveName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(AppIcons.chevron_right, size: 20, color: AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...List.generate(5, (i) {
                            IconData icon;
                            if (i < full) {
                              icon = AppIcons.star;
                            } else if (i == full && hasHalf) {
                              icon = AppIcons.star_half;
                            } else {
                              icon = AppIcons.star_border;
                            }
                            return Icon(
                              icon,
                              size: 18,
                              color: AppColors.warning,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            reviewCount.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 12),
                            const Icon(AppIcons.verified, size: 18, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '本人確認済',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hourlyRate != null)
                        Text(
                          '¥$hourlyRate / 時間',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 出品者向けのみ表示（購入者プロフィールでは非表示）
class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({required this.uid});

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
          final data = snapshot.data!.data()!;
          final raw = data['walletBalance'];
          if (raw is num) {
            balance = raw.toInt();
          }
        }

        final formatted = '¥${NumberFormat('#,###').format(balance)}';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '売上残高',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: uid == null ? null : () => context.push('/mypage/withdraw'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: AppSpacing.md),
              ),
              child: const Text('売上を出金'),
            ),
          ],
        );
      },
    );
  }
}

class _BuyerMenuList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 依頼・取引は上の統計カードから開けるためメニューでは省略
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MenuTile(
          icon: AppIcons.settings,
          label: 'アカウント設定',
          onTap: () => context.push('/settings/account'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.favorite_border,
          label: 'いいねリスト',
          onTap: () => context.push('/mypage/likes'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.notifications_outlined,
          label: '通知設定',
          onTap: () => context.push('/settings/notifications'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.verified_user_outlined,
          label: '本人確認',
          onTap: () => context.push('/settings/identity'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.help_outline,
          label: 'ヘルプ/お問い合わせ',
          onTap: () => context.push('/help'),
        ),
      ],
    );
  }
}

class _SellerMenuList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 新規依頼・取引・完了は統計カードから。出品一覧とStripeはここだけ
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MenuTile(
          icon: AppIcons.settings,
          label: 'アカウント設定',
          onTap: () => context.push('/settings/account'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.grid_view_outlined,
          label: '出品一覧',
          onTap: () => context.push('/mypage/listings'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.account_balance_wallet_outlined,
          label: 'Stripeアカウント連携',
          onTap: () => context.push('/mypage/stripe'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.favorite_border,
          label: 'いいねしてくれたユーザー',
          onTap: () => context.push('/mypage/likes'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.notifications_outlined,
          label: '通知設定',
          onTap: () => context.push('/settings/notifications'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.verified_user_outlined,
          label: '本人確認',
          onTap: () => context.push('/settings/identity'),
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: AppIcons.help_outline,
          label: 'ヘルプ/お問い合わせ',
          onTap: () => context.push('/help'),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(AppIcons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
