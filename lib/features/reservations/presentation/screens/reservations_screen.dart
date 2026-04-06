import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../profile/presentation/providers/profile_mode_provider.dart';

class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final mode = ref.watch(profileModeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '予約',
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.listHorizontal,
          AppSpacing.md,
          AppSpacing.listHorizontal,
          AppSpacing.md + AppSpacing.bottomForFloatingShell(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '依頼・取引の管理',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (mode == ProfileMode.buyer)
              _BuyerReservationCards(uid: uid)
            else
              _SellerReservationCards(uid: uid),
            const SizedBox(height: 24),
            const Text(
              'ショートカット',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: AppIcons.assignment_outlined,
              label: mode == ProfileMode.buyer ? '依頼したサービス' : '新規依頼',
              onTap: () => context.push(
                mode == ProfileMode.buyer ? '/mypage/requests' : '/seller/requests',
              ),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: AppIcons.inventory_2_outlined,
              label: '取引中',
              onTap: () => context.push('/mypage/transactions'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: AppIcons.check_circle_outline,
              label: '完了',
              onTap: () => context.push('/mypage/completed'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyerReservationCards extends StatelessWidget {
  const _BuyerReservationCards({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: uid == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('serviceRequests')
                    .where('buyerId', isEqualTo: uid)
                    .where('status', whereIn: ['requested', 'approved'])
                    .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _StatCard(
                icon: AppIcons.assignment_outlined,
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
                    .where('buyerId', isEqualTo: uid)
                    .snapshots(),
            builder: (context, snapshot) {
              final txCount = (snapshot.data?.docs ?? const []).where((d) {
                final status = (d.data()['status'] as String?)?.trim().toLowerCase();
                return status != null &&
                    status.isNotEmpty &&
                    status != 'completed' &&
                    status != 'reviewed' &&
                    status != 'failed' &&
                    status != 'cancelled' &&
                    status != 'canceled';
              }).length;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: uid == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('serviceRequests')
                        .where('buyerId', isEqualTo: uid)
                        .snapshots(),
                builder: (context, requestSnap) {
                  final pendingRequestCount = (requestSnap.data?.docs ?? const [])
                      .where((d) {
                        final data = d.data();
                        final status = (data['status'] as String?)?.trim().toLowerCase();
                        if (status == null ||
                            status.isEmpty ||
                            status == 'rejected' ||
                            status == 'completed' ||
                            status == 'cancelled' ||
                            status == 'canceled') {
                          return false;
                        }
                        final txId = d.data()['transactionId'] as String?;
                        return txId == null || txId.isEmpty;
                      })
                      .length;
                  return _StatCard(
                    icon: AppIcons.inventory_2_outlined,
                    label: '取引中',
                    count: txCount + pendingRequestCount,
                    onTap: () => context.push('/mypage/transactions'),
                  );
                },
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
                    .where('buyerId', isEqualTo: uid)
                    .where('status', whereIn: ['completed', 'reviewed'])
                    .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _StatCard(
                icon: AppIcons.check_circle_outline,
                label: '完了',
                count: count,
                onTap: () => context.push('/mypage/completed'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SellerReservationCards extends StatelessWidget {
  const _SellerReservationCards({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: uid == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('serviceRequests')
                    .where('sellerId', isEqualTo: uid)
                    .where('status', isEqualTo: 'requested')
                    .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _StatCard(
                icon: AppIcons.mark_email_unread_outlined,
                label: '新規依頼',
                count: count,
                onTap: () => context.push('/seller/requests'),
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
                    .where('sellerId', isEqualTo: uid)
                    .snapshots(),
            builder: (context, snapshot) {
              final txCount = (snapshot.data?.docs ?? const []).where((d) {
                final status = (d.data()['status'] as String?)?.trim().toLowerCase();
                return status != null &&
                    status.isNotEmpty &&
                    status != 'completed' &&
                    status != 'reviewed' &&
                    status != 'failed' &&
                    status != 'cancelled' &&
                    status != 'canceled';
              }).length;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: uid == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('serviceRequests')
                        .where('sellerId', isEqualTo: uid)
                        .snapshots(),
                builder: (context, requestSnap) {
                  final pendingRequestCount = (requestSnap.data?.docs ?? const [])
                      .where((d) {
                        final data = d.data();
                        final status = (data['status'] as String?)?.trim().toLowerCase();
                        if (status == null ||
                            status.isEmpty ||
                            status == 'rejected' ||
                            status == 'completed' ||
                            status == 'cancelled' ||
                            status == 'canceled') {
                          return false;
                        }
                        final txId = d.data()['transactionId'] as String?;
                        return txId == null || txId.isEmpty;
                      })
                      .length;
                  return _StatCard(
                    icon: AppIcons.inventory_2_outlined,
                    label: '取引中',
                    count: txCount + pendingRequestCount,
                    onTap: () => context.push('/mypage/transactions'),
                  );
                },
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
                    .where('sellerId', isEqualTo: uid)
                    .where('status', whereIn: ['completed', 'reviewed'])
                    .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _StatCard(
                icon: AppIcons.check_circle_outline,
                label: '完了',
                count: count,
                onTap: () => context.push('/mypage/completed'),
              );
            },
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${count}件',
                style: const TextStyle(
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
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.listHorizontal,
            vertical: 14,
          ),
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

