// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetServerInfoResponse _$GetServerInfoResponseFromJson(
    Map<String, dynamic> json) {
  return GetServerInfoResponse(
    uuid: json['uuid'] as String,
    version: json['version'] as String,
  );
}

Map<String, dynamic> _$GetServerInfoResponseToJson(
        GetServerInfoResponse instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'version': instance.version,
    };
