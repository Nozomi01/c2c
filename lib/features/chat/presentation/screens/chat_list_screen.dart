import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/app_theme.dart';
import '../../domain/models/chat.dart';
import '../providers/chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    final chatsAsync = ref.watch(userChatsWithUnreadProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: chatsAsync.when(
        data: (chatsWithUnread) {
          if (chatsWithUnread.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'メッセージはありません',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chatsWithUnread.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final item = chatsWithUnread[index];
              final otherId = item.chat.users.firstWhere((u) => u != user.uid, orElse: () => '');
              return _ChatListTile(
                chat: item.chat,
                unreadCount: item.unreadCount,
                currentUserId: user.uid,
                otherUserId: otherId,
                onTap: () => context.push('/chats/${item.chat.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'メッセージ',
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

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.chat,
    required this.unreadCount,
    required this.currentUserId,
    required this.otherUserId,
    required this.onTap,
  });

  final Chat chat;
  final int unreadCount;
  final String currentUserId;
  final String otherUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeStr = chat.updatedAt != null
        ? DateFormat('M/d HH:mm').format(chat.updatedAt!)
        : '';

    if (otherUserId.isEmpty) {
      return _buildTile(
        context,
        title: 'チャット',
        timeStr: timeStr,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, userSnap) {
        final data = userSnap.data?.data() ?? <String, dynamic>{};
        final name = (data['displayName'] as String?)?.trim();
        final email = (data['email'] as String?)?.trim();
        final emailPrefix = email != null && email.contains('@')
            ? email.split('@').first
            : null;
        final title =
            (name == null || name.isEmpty) ? (emailPrefix ?? 'ユーザー') : name;

        return _buildTile(
          context,
          title: title,
          timeStr: timeStr,
        );
      },
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    required String timeStr,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        title.isNotEmpty ? title[0] : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage ?? 'メッセージを送信しましょう',
                      style: TextStyle(
                        fontSize: 14,
                        color: unreadCount > 0
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
