import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'service.freezed.dart';
part 'service.g.dart';

@freezed
class Service with _$Service {
  const factory Service({
    required String id,
    required String ownerId,
    required String title,
    required String description,
    required String category,
    required int price,
    required int duration,
    required String location,
    required bool onlineAvailable,
    required bool offlineAvailable,
    @Default(<String>[]) List<String> images,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
    required DateTime createdAt,
  }) = _Service;

  factory Service.fromJson(Map<String, dynamic> json) => _$ServiceFromJson(json);

  factory Service.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Service.fromJson({
      'id': doc.id,
      ...data,
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
    });
  }
}

