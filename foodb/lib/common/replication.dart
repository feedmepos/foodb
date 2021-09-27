import 'package:json_annotation/json_annotation.dart';

part 'replication.g.dart';

@JsonSerializable(explicitToJson: true)
class ReplicationLog {
  List<History> history;

  @JsonKey(name: 'replication_id_version')
  int replicationIdVersion;

  @JsonKey(name: 'session_id')
  String sessionId;

  @JsonKey(name: 'source_last_seq')
  String sourceLastSeq;

  ReplicationLog({
    required this.history,
    required this.replicationIdVersion,
    required this.sessionId,
    required this.sourceLastSeq,
  });

  factory ReplicationLog.fromJson(Map<String, dynamic> json) =>
      _$ReplicationLogFromJson(json);
  Map<String, dynamic> toJson() => _$ReplicationLogToJson(this);
}

@JsonSerializable()
class History {
  @JsonKey(name: 'session_id')
  String sessionId;

  @JsonKey(name: 'start_time')
  String startTime;

  @JsonKey(name: 'end_time')
  String endTime;

  @JsonKey(name: 'recorded_seq')
  String recordedSeq;

  History({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.recordedSeq,
  });

  factory History.fromJson(Map<String, dynamic> json) =>
      _$HistoryFromJson(json);
  Map<String, dynamic> toJson() => _$HistoryToJson(this);
}
