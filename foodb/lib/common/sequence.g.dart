// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sequence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SequenceLog _$SequenceLogFromJson(Map<String, dynamic> json) {
  return SequenceLog(
    json['seq'] as int,
    json['id'] as String,
    json['changes'] as String,
    json['deleted'] as String?,
    json['data'] as String,
    json['rev'] as String,
  );
}

Map<String, dynamic> _$SequenceLogToJson(SequenceLog instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'id': instance.id,
      'changes': instance.changes,
      'deleted': instance.deleted,
      'data': instance.data,
      'rev': instance.rev,
    };
