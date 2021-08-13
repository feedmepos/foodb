// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_docs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BulkDocResponse _$BulkDocResponseFromJson(Map<String, dynamic> json) {
  return BulkDocResponse(
    putResponses: (json['putResponses'] as List<dynamic>?)
        ?.map((e) => PutResponse.fromJson(e as Map<String, dynamic>))
        .toList(),
    error: json['error'] as String?,
    reason: json['reason'] as String?,
  );
}

Map<String, dynamic> _$BulkDocResponseToJson(BulkDocResponse instance) =>
    <String, dynamic>{
      'putResponses': instance.putResponses?.map((e) => e.toJson()).toList(),
      'error': instance.error,
      'reason': instance.reason,
    };
