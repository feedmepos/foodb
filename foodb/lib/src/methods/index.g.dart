// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IndexResponse _$IndexResponseFromJson(Map<String, dynamic> json) {
  return IndexResponse(
    result: json['result'] as String,
    id: json['id'] as String,
    name: json['name'] as String,
  );
}

Map<String, dynamic> _$IndexResponseToJson(IndexResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
      'id': instance.id,
      'name': instance.name,
    };

DeleteIndexResponse _$DeleteIndexResponseFromJson(Map<String, dynamic> json) {
  return DeleteIndexResponse(
    ok: json['ok'] as bool,
  );
}

Map<String, dynamic> _$DeleteIndexResponseToJson(
        DeleteIndexResponse instance) =>
    <String, dynamic>{
      'ok': instance.ok,
    };
