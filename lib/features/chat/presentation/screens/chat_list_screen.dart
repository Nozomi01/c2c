import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../domain/models/chat.dart';
import '../providers/chat_providers.dart';

final List<BoxShadow> _kChatCardShadow = [
  const BoxShadow(
    color: Color(0x14000000),
    blurRadius: 14,
    offset: Offset(0, 4),
  ),
  const BoxShadow(
    color: Color(0x08000000),
    blurRadius: 6,
    offset: Offset(0, 2),
  ),
];

const double _kChatCardRadius = 22;

/// Time in header row: today → HH:mm, else M/d
String _formatChatListTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return DateFormat('HH:mm').format(t);
  }
  return DateFormat('M/d').format(t);
}

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
                  Icon(AppIcons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.listHorizontal,
              12,
              AppSpacing.listHorizontal,
              8 + AppSpacing.bottomForFloatingShell(context),
            ),
            itemCount: chatsWithUnread.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
      centerTitle: false,
      titleSpacing: AppSpacing.listHorizontal,
      title: const Text(
        'メッセージ',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.3,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFF3F4F6),
        ),
      ),
      actions: [
        IconButton(
          tooltip: '通知',
          onPressed: () => context.push('/notifications'),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF3F4F6),
            foregroundColor: AppColors.textSecondary,
          ),
          icon: const Icon(AppIcons.notifications_outlined, size: 22),
        ),
        const SizedBox(width: 8),
      ],
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
    final timeStr = _formatChatListTime(chat.updatedAt);

    if (otherUserId.isEmpty) {
      return _ChatCard(
        onTap: onTap,
        title: 'チャット',
        timeStr: timeStr,
        preview: chat.lastMessage ?? 'メッセージを送信しましょう',
        unreadCount: unreadCount,
        photoUrl: null,
        isVerified: false,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, userSnap) {
        final data = userSnap.data?.data() ?? <String, dynamic>{};
        final name = (data['displayName'] as String?)?.trim();
        final email = (data['email'] as String?)?.trim();
        final emailPrefix = email != null && email.contains('@') ? email.split('@').first : null;
        final title = (name == null || name.isEmpty) ? (emailPrefix ?? 'ユーザー') : name;
        final photoUrl = (data['photoURL'] as String?)?.trim();
        final verifiedRaw = data['isVerified'] ?? data['verified'];
        final isVerified = verifiedRaw == true;

        return _ChatCard(
          onTap: onTap,
          title: title,
          timeStr: timeStr,
          preview: chat.lastMessage ?? 'メッセージを送信しましょう',
          unreadCount: unreadCount,
          photoUrl: (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
          isVerified: isVerified,
        );
      },
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.onTap,
    required this.title,
    required this.timeStr,
    required this.preview,
    required this.unreadCount,
    required this.photoUrl,
    required this.isVerified,
  });

  final VoidCallback onTap;
  final String title;
  final String timeStr;
  final String preview;
  final int unreadCount;
  final String? photoUrl;
  final bool isVerified;

  static const Color _timeColor = Color(0xFF818CF8);
  static const Color _previewColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(_kChatCardRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: _kChatCardShadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: photoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: photoUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _avatarFallback(title),
                                )
                              : _avatarFallback(title),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      AppIcons.verified,
                                      size: 17,
                                      color: Color(0xFF1DA1F2),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _timeColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                            color: unreadCount > 0 ? AppColors.textPrimary : _previewColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String title) {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFE8EAED),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? String.fromCharCode(title.runes.first) : '?',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
