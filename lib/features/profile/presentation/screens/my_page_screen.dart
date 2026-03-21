import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // プロフィール（Firestoreのrating/reviewCount/isVerifiedを反映）
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

                final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;
                final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
                final verified = verifiedRaw is bool ? verifiedRaw : false;

                final r = (rating.isFinite ? rating : 0.0).clamp(0.0, 5.0);
                final full = r.floor().clamp(0, 5);
                final hasHalf = (r - full) >= 0.5 && full < 5;

                return InkWell(
                  onTap: () => context.push('/settings/profile'),
                  borderRadius: BorderRadius.circular(12),
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
                                  Icon(Icons.chevron_right,
                                      size: 20, color: AppColors.textSecondary),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  ...List.generate(5, (i) {
                                    IconData icon;
                                    if (i < full) {
                                      icon = Icons.star;
                                    } else if (i == full && hasHalf) {
                                      icon = Icons.star_half;
                                    } else {
                                      icon = Icons.star_border;
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
                                    const Icon(Icons.verified,
                                        size: 18, color: AppColors.success),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 残高
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                          '残高',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('売上を出金'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 3つのカード: 申し込み中 / 取引中 / 完了
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: uid == null
                        ? const Stream.empty()
                        : FirebaseFirestore.instance
                            .collection('serviceRequests')
                            .where('buyerId', isEqualTo: uid)
                            .where('status', whereIn: ['pending', 'approved'])
                            .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _StatCard(
                        icon: Icons.assignment_outlined,
                        label: '申し込み中',
                        count: count,
                        onTap: () => context.push('/mypage/requests'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: uid == null
                        ? const Stream.empty()
                        : FirebaseFirestore.instance
                            .collection('transactions')
                            .where('participantIds', arrayContains: uid)
                            .where('status', whereIn: ['pending', 'paid', 'inProgress'])
                            .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _StatCard(
                        icon: Icons.inventory_2_outlined,
                        label: '取引中',
                        count: count,
                        onTap: () => context.push('/mypage/transactions'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: uid == null
                        ? const Stream.empty()
                        : FirebaseFirestore.instance
                            .collection('serviceRequests')
                            .where('sellerId', isEqualTo: uid)
                            .where('status', isEqualTo: 'completed')
                            .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _StatCard(
                        icon: Icons.check_circle_outline,
                        label: '完了',
                        count: count,
                        onTap: () => context.push('/mypage/completed'),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // メニューリスト
            _MenuTile(
              icon: Icons.settings,
              label: 'アカウント設定',
              onTap: () => context.push('/settings/account'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.assignment_outlined,
              label: '依頼したサービス',
              onTap: () => context.push('/mypage/requests'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.assignment_ind_outlined,
              label: '受けている依頼',
              onTap: () => context.push('/seller/requests'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.verified_user_outlined,
              label: '本人確認',
              onTap: () => context.push('/settings/identity'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.notifications_outlined,
              label: '通知設定',
              onTap: () => context.push('/settings/notifications'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Stripeアカウント連携',
              onTap: () => context.push('/mypage/stripe'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.favorite_border,
              label: 'いいねリスト',
              onTap: () => context.push('/mypage/likes'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.info_outline,
              label: 'サービスについて',
              onTap: () => context.push('/about'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.help_outline,
              label: 'ヘルプ/お問い合わせ',
              onTap: () => context.push('/help'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${count}件',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
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
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
