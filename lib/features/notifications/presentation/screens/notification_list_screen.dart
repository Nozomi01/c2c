import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../providers/notification_providers.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: notificationsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'お知らせはまだありません',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: AppSpacing.sm),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];
              final time = DateFormat('M/d HH:mm').format(n.createdAt);
              return InkWell(
                onTap: () async {
                  // Mark as read on tap
                  if (!n.read) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(n.id)
                          .update({'read': true});
                    } catch (_) {
                      // ignore tap error
                    }
                  }

                  // Navigate to suitable page based on notification type/data
                  if (n.type == 'chat') {
                    final docId = n.id;
                    try {
                      final snap = await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(docId)
                          .get();
                      final raw = snap.data();
                      final extraRaw = raw?['data'];
                      final extra = extraRaw is Map
                          ? Map<String, dynamic>.from(extraRaw)
                          : <String, dynamic>{};
                      final chatId = extra['chatId'] as String?;
                      if (context.mounted) {
                        if (chatId != null && chatId.isNotEmpty) {
                          context.push('/chats/$chatId');
                        } else {
                          context.push('/messages');
                        }
                      }
                    } catch (_) {
                      // ignore navigation error
                    }
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: 14),
                  decoration: BoxDecoration(
                    color: n.read
                        ? Colors.grey.shade100
                        : AppColors.primarySoft.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    n.read ? FontWeight.w500 : FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints.tightFor(width: 32, height: 32),
                            icon: Icon(
                              n.read ? AppIcons.mark_email_read : AppIcons.mark_email_unread_outlined,
                              color: n.read
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                            ),
                            onPressed: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .doc(n.id)
                                    .update({'read': !n.read});
                              } catch (_) {
                                // ignore toggle error
                              }
                            },
                            tooltip: n.read ? '未読にする' : '既読にする',
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(AppIcons.chevron_left),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'お知らせ',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;
            try {
              final db = FirebaseFirestore.instance;
              final snap = await db
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .get();
              final batch = db.batch();
              for (final doc in snap.docs) {
                batch.update(doc.reference, {'read': true});
              }
              await batch.commit();
            } catch (_) {
              // ignore errors for "mark all read"
            }
          },
          child: const Text(
            'すべて既読',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
    );
  }
}

