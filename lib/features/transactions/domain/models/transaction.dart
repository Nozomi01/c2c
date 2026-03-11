import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionStatus {
  pending,
  paid,
  inProgress,
  completed,
  reviewed,
}

@freezed
class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required String id,
    required String serviceId,
    required String buyerId,
    required String sellerId,
    required int price,
    required TransactionStatus status,
    required DateTime createdAt,
    DateTime? meetingDate,
    String? meetingLocation,
  }) = _TransactionModel;

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);

  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TransactionModel.fromJson({
      'id': doc.id,
      ...data,
      'createdAt':
          (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'meetingDate':
          (data['meetingDate'] as Timestamp?)?.toDate().toIso8601String(),
    });
  }
}

