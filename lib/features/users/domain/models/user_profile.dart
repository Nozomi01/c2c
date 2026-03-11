import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String name,
    String? avatar,
    String? bio,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
    String? location,
    @Default(false) bool isVerified,
    @Default(0) int walletBalance,
    required DateTime createdAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserProfile.fromJson({
      'id': doc.id,
      ...data,
      'createdAt':
          (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
    });
  }
}

