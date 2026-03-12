import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/chat.dart';
import '../domain/models/message.dart';

abstract class ChatRepository {
  Stream<List<Chat>> watchUserChats(String userId);
  Stream<List<ChatWithUnread>> watchUserChatsWithUnread(String userId);
  Stream<Chat?> watchChat(String chatId);
  Stream<List<Message>> watchMessages(String chatId);
  Future<String> findOrCreateChat(String userId1, String userId2);
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  });
  Future<void> markMessagesAsRead(String chatId, String userId);
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
  Stream<List<ChatWithUnread>> watchUserChatsWithUnread(String userId) {
    return _chats
        .where('users', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) {
              final chat = Chat.fromFirestore(doc);
              final data = doc.data();
              final unreadMap = data['unread'];
              int count = 0;
              if (unreadMap is Map && unreadMap.containsKey(userId)) {
                final v = unreadMap[userId];
                count = v is int ? v : (v is num ? v.toInt() : 0);
              }
              return ChatWithUnread(chat, count);
            }).toList());
  }

  @override
  Stream<Chat?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return Chat.fromFirestore(s);
    });
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
  Future<String> findOrCreateChat(String userId1, String userId2) async {
    final snapshot = await _chats
        .where('users', arrayContains: userId1)
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final users = List<String>.from(data['users'] as List<dynamic>? ?? []);
      if (users.contains(userId2)) return doc.id;
    }
    final doc = await _chats.add({
      'users': [userId1, userId2],
      'lastMessage': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'unread': {userId1: 0, userId2: 0},
    });
    return doc.id;
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

    final chatDoc = await _chats.doc(chatId).get();
    final data = chatDoc.data();
    final users = List<String>.from(data?['users'] as List<dynamic>? ?? []);
    final recipientId = users.where((u) => u != senderId).firstOrNull;
    final updates = <String, dynamic>{
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (recipientId != null) {
      final unread = Map<String, dynamic>.from(data?['unread'] as Map? ?? {});
      final current = unread[recipientId];
      final next = (current is int ? current : (current is num ? current.toInt() : 0)) + 1;
      unread[recipientId] = next;
      updates['unread'] = unread;
    }
    await _chats.doc(chatId).update(updates);

    return doc.id;
  }

  @override
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final batch = _firestore.batch();
    final chatRef = _chats.doc(chatId);
    final messagesSnapshot = await _messages
        .where('chatId', isEqualTo: chatId)
        .get();
    for (final doc in messagesSnapshot.docs) {
      final data = doc.data();
      if (data['senderId'] != userId && data['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    batch.update(chatRef, {
      'unread.$userId': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

