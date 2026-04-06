import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat_repository.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';

final _firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return FirestoreChatRepository(ref.watch(_firestoreProvider));
});

final userChatsProvider =
    StreamProvider.family<List<Chat>, String>((ref, userId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchUserChats(userId);
});

final userChatsWithUnreadProvider =
    StreamProvider.family<List<ChatWithUnread>, String>((ref, userId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchUserChatsWithUnread(userId);
});

/// Any chat with unread messages — drives the messages tab red dot on the main shell.
final hasAnyChatUnreadProvider = Provider<bool>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final chats = ref.watch(userChatsWithUnreadProvider(uid));
  return chats.maybeWhen(
    data: (list) => list.any((c) => c.unreadCount > 0),
    orElse: () => false,
  );
});

final chatDetailProvider =
    StreamProvider.family<Chat?, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchChat(chatId);
});

final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchMessages(chatId);
});

