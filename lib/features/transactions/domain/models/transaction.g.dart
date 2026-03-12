// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionModelImpl _$$TransactionModelImplFromJson(
  Map<String, dynamic> json,
) => _$TransactionModelImpl(
  id: json['id'] as String,
  serviceId: json['serviceId'] as String,
  buyerId: json['buyerId'] as String,
  sellerId: json['sellerId'] as String,
  price: (json['price'] as num).toInt(),
  status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  meetingDate: json['meetingDate'] == null
      ? null
      : DateTime.parse(json['meetingDate'] as String),
  meetingLocation: json['meetingLocation'] as String?,
);

Map<String, dynamic> _$$TransactionModelImplToJson(
  _$TransactionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'serviceId': instance.serviceId,
  'buyerId': instance.buyerId,
  'sellerId': instance.sellerId,
  'price': instance.price,
  'status': _$TransactionStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'meetingDate': instance.meetingDate?.toIso8601String(),
  'meetingLocation': instance.meetingLocation,
};

const _$TransactionStatusEnumMap = {
  TransactionStatus.pending: 'pending',
  TransactionStatus.paid: 'paid',
  TransactionStatus.inProgress: 'inProgress',
  TransactionStatus.completed: 'completed',
  TransactionStatus.reviewed: 'reviewed',
};
