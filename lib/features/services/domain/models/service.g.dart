// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServiceImpl _$$ServiceImplFromJson(Map<String, dynamic> json) =>
    _$ServiceImpl(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      location: json['location'] as String,
      onlineAvailable: json['onlineAvailable'] as bool,
      offlineAvailable: json['offlineAvailable'] as bool,
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ServiceImplToJson(_$ServiceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerId': instance.ownerId,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'price': instance.price,
      'duration': instance.duration,
      'location': instance.location,
      'onlineAvailable': instance.onlineAvailable,
      'offlineAvailable': instance.offlineAvailable,
      'images': instance.images,
      'rating': instance.rating,
      'reviewCount': instance.reviewCount,
      'createdAt': instance.createdAt.toIso8601String(),
    };
