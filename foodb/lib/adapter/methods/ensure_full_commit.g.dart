// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ensure_full_commit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnsureFullCommitResponse _$EnsureFullCommitResponseFromJson(
    Map<String, dynamic> json) {
  return EnsureFullCommitResponse(
    instanceStartTime: json['instance_start_time'] as String,
    ok: json['ok'] as bool,
  );
}

Map<String, dynamic> _$EnsureFullCommitResponseToJson(
        EnsureFullCommitResponse instance) =>
    <String, dynamic>{
      'instance_start_time': instance.instanceStartTime,
      'ok': instance.ok,
    };
