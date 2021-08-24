// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteResponse _$DeleteResponseFromJson(Map<String, dynamic> json) {
  return DeleteResponse(
    ok: json['ok'] as bool,
    id: json['id'] as String,
    rev: RevFromJsonString(json['rev'] as String?),
  );
}

Map<String, dynamic> _$DeleteResponseToJson(DeleteResponse instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'id': instance.id,
      'rev': RevToJsonString(instance.rev),
    };
