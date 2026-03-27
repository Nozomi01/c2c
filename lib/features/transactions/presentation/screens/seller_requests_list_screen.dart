import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';

/// 単純なリクエストモデル（Firestore の `serviceRequests` コレクションを想定）
class ServiceRequest {
  ServiceRequest({
    required this.id,
    required this.serviceTitle,
    required this.buyerName,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String serviceTitle;
  final String buyerName;
  final DateTime createdAt;
  final String status; // requested / approved / rejected / changed ...

  factory ServiceRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ServiceRequest(
      id: doc.id,
      serviceTitle: data['serviceTitle'] as String? ?? 'サービス',
      buyerName: data['buyerName'] as String? ?? '購入者',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'requested',
    );
  }
}

final sellerRequestsProvider = StreamProvider.autoDispose<List<ServiceRequest>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();

  final query = FirebaseFirestore.instance
      .collection('serviceRequests')
      .where('sellerId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'requested')
      .orderBy('createdAt', descending: true);

  return query.snapshots().map(
        (snap) => snap.docs.map(ServiceRequest.fromDoc).toList(),
      );
});

class SellerRequestsListScreen extends ConsumerWidget {
  const SellerRequestsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: const _RequestsList(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(AppIcons.chevron_left),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        '受けている依頼',
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
    );
  }
}

class _RequestsList extends ConsumerWidget {
  const _RequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRequests = ref.watch(sellerRequestsProvider);
    return asyncRequests.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.assignment_outlined, size: 64, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text(
                  '受けている依頼はありません',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = list[index];
            return _RequestTile(request: r);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final ServiceRequest request;

  String get _statusLabel {
    switch (request.status) {
      case 'approved':
        return '承認済み';
      case 'paid':
        return '支払い済み';
      case 'inProgress':
        return '提供中';
      case 'rejected':
        return '却下';
      case 'changed':
        return '条件変更提案中';
      default:
        return '新しい依頼';
    }
  }

  Color get _statusColor {
    switch (request.status) {
      case 'approved':
        return AppColors.success;
      case 'paid':
        return AppColors.primary;
      case 'inProgress':
        return Colors.blueAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'changed':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('yyyy/MM/dd HH:mm').format(request.createdAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Text(
        request.serviceTitle,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '依頼者: ${request.buyerName}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 11,
                color: _statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Icon(AppIcons.chevron_right, size: 18, color: AppColors.textSecondary),
        ],
      ),
      onTap: () {
        context.push('/seller/requests/${request.id}');
      },
    );
  }
}

