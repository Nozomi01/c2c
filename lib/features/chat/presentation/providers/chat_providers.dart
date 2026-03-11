import 'package:cloud_firestore/cloud_firestore.dart';
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

final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchMessages(chatId);
});

