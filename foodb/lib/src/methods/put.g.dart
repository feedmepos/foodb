// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutResponse _$PutResponseFromJson(Map<String, dynamic> json) {
  return PutResponse(
    ok: json['ok'] as bool,
    id: json['id'] as String,
    rev: RevFromJsonString(json['rev'] as String?),
  );
}

Map<String, dynamic> _$PutResponseToJson(PutResponse instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'id': instance.id,
      'rev': RevToJsonString(instance.rev),
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
