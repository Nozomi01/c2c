import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('ログインが必要です')),
      );
    }

    final chatsAsync = ref.watch(userChatsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージ'),
      ),
      body: chatsAsync.when(
        data: (chats) => ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (context, index) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              title: Text(chat.lastMessage ?? '新しいチャット'),
              subtitle: Text(chat.id),
              onTap: () {
                context.pushNamed(
                  'chatThread',
                  pathParameters: {'id': chat.id},
                );
              },
            );
          },
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, st) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

