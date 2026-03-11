import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/chat.dart';
import '../domain/models/message.dart';

abstract class ChatRepository {
  Stream<List<Chat>> watchUserChats(String userId);
  Stream<List<Message>> watchMessages(String chatId);
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  });
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('messages');

  @override
  Stream<List<Chat>> watchUserChats(String userId) {
    return _chats
        .where('users', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Chat.fromFirestore).toList());
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    return _messages
        .where('chatId', isEqualTo: chatId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Message.fromFirestore).toList());
  }

  @override
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final doc = await _messages.add({
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await _chats.doc(chatId).update({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }
}

