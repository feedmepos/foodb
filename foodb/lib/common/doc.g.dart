// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Revisions _$RevisionsFromJson(Map<String, dynamic> json) {
  return Revisions(
    start: json['start'] as int,
    ids: (json['ids'] as List<dynamic>).map((e) => e as String).toList(),
  );
}

Map<String, dynamic> _$RevisionsToJson(Revisions instance) => <String, dynamic>{
      'start': instance.start,
      'ids': instance.ids,
    };

RevsInfo _$RevsInfoFromJson(Map<String, dynamic> json) {
  return RevsInfo(
    rev: RevFromJsonString(json['rev'] as String?),
    status: json['status'] as String,
  );
}

Map<String, dynamic> _$RevsInfoToJson(RevsInfo instance) => <String, dynamic>{
      'rev': RevToJsonString(instance.rev),
      'status': instance.status,
    };
