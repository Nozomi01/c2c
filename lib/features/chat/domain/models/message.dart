import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String chatId,
    required String senderId,
    String? text,
    String? image,
    required DateTime createdAt,
    @Default(false) bool isRead,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final createdAt = data['createdAt'];
    final createdAtStr = createdAt is Timestamp
        ? createdAt.toDate().toIso8601String()
        : DateTime.now().toIso8601String();
    return Message.fromJson({
      'id': doc.id,
      ...data,
      'createdAt': createdAtStr,
    });
  }
}

