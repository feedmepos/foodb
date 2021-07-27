// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteResponse _$DeleteResponseFromJson(Map<String, dynamic> json) {
  return DeleteResponse(
    ok: json['ok'] as bool?,
    id: json['id'] as String?,
    rev: json['rev'] as String?,
    error: json['error'] as String?,
    reason: json['reason'] as String?,
  );
}

Map<String, dynamic> _$DeleteResponseToJson(DeleteResponse instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'id': instance.id,
      'rev': instance.rev,
      'error': instance.error,
      'reason': instance.reason,
    };
