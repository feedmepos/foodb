import 'package:json_annotation/json_annotation.dart';

part 'sequence.g.dart';

@JsonSerializable()
class SequenceLog {
  int seq;
  String id;
  String changes;
  String? deleted;
  String data;
  String rev;

  SequenceLog(
    this.seq,
    this.id,
    this.changes,
    this.deleted,
    this.data,
    this.rev,
  );

  factory SequenceLog.fromJson(Map<String, dynamic> json) =>
      _$SequenceLogFromJson(json);
  Map<String, dynamic> toJson() => _$SequenceLogToJson(this);
}
