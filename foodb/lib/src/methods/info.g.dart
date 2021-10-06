// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetInfoResponse _$GetInfoResponseFromJson(Map<String, dynamic> json) {
  return GetInfoResponse(
    instanceStartTime: json['instance_start_time'] as String,
    updateSeq: json['update_seq'] as String,
    dbName: json['db_name'] as String,
  );
}

Map<String, dynamic> _$GetInfoResponseToJson(GetInfoResponse instance) =>
    <String, dynamic>{
      'instance_start_time': instance.instanceStartTime,
      'update_seq': instance.updateSeq,
      'db_name': instance.dbName,
    };
