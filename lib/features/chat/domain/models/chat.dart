import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required List<String> users,
    String? lastMessage,
    DateTime? updatedAt,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  factory Chat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Chat.fromJson({
      'id': doc.id,
      ...data,
      'updatedAt':
          (data['updatedAt'] as Timestamp?)?.toDate().toIso8601String(),
    });
  }
}

