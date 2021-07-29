// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutResponse _$PutResponseFromJson(Map<String, dynamic> json) {
  return PutResponse(
    ok: json['ok'] as bool?,
    id: json['id'] as String?,
    rev: json['rev'] as String?,
    error: json['error'] as String?,
    reason: json['reason'] as String?,
  );
}

Map<String, dynamic> _$PutResponseToJson(PutResponse instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'id': instance.id,
      'rev': instance.rev,
      'error': instance.error,
      'reason': instance.reason,
    };

PutRequestBody _$PutRequestBodyFromJson(Map<String, dynamic> json) {
  return PutRequestBody(
    rev: json['rev'] as String?,
  );
}

Map<String, dynamic> _$PutRequestBodyToJson(PutRequestBody instance) =>
    <String, dynamic>{
      'rev': instance.rev,
    };
