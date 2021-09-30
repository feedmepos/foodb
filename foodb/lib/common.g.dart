// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common.dart';

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

ReplicationLog _$ReplicationLogFromJson(Map<String, dynamic> json) {
  return ReplicationLog(
    history: (json['history'] as List<dynamic>)
        .map((e) => History.fromJson(e as Map<String, dynamic>))
        .toList(),
    replicationIdVersion: json['replication_id_version'] as int,
    sessionId: json['session_id'] as String,
    sourceLastSeq: json['source_last_seq'] as String,
  );
}

Map<String, dynamic> _$ReplicationLogToJson(ReplicationLog instance) =>
    <String, dynamic>{
      'history': instance.history.map((e) => e.toJson()).toList(),
      'replication_id_version': instance.replicationIdVersion,
      'session_id': instance.sessionId,
      'source_last_seq': instance.sourceLastSeq,
    };

History _$HistoryFromJson(Map<String, dynamic> json) {
  return History(
    sessionId: json['session_id'] as String,
    startTime: json['start_time'] as String,
    endTime: json['end_time'] as String,
    recordedSeq: json['recorded_seq'] as String,
  );
}

Map<String, dynamic> _$HistoryToJson(History instance) => <String, dynamic>{
      'session_id': instance.sessionId,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'recorded_seq': instance.recordedSeq,
    };
