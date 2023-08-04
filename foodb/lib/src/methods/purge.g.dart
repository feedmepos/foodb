// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurgeResponse _$PurgeResponseFromJson(Map<String, dynamic> json) {
  return PurgeResponse(
    purgeSeq: json['purge_seq'] as String?,
    purged: (json['purged'] as Map<String, dynamic>?)?.map(
      (k, e) =>
          MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
    ),
  );
}

Map<String, dynamic> _$PurgeResponseToJson(PurgeResponse instance) =>
    <String, dynamic>{
      'purge_seq': instance.purgeSeq,
      'purged': instance.purged,
    };
