import 'package:json_annotation/json_annotation.dart';

part 'info.g.dart';

@JsonSerializable()
class GetInfoResponse {
  @JsonKey(name: 'instance_start_time')
  String instanceStartTime;
  @JsonKey(name: 'update_seq')
  String updateSeq;
  @JsonKey(name: 'db_name')
  String dbName;
  @JsonKey(name: 'doc_count')
  int docCount;
  GetInfoResponse({
    required this.instanceStartTime,
    required this.updateSeq,
    required this.dbName,
    required this.docCount,
  });

  factory GetInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$GetInfoResponseFromJson(json);
  Map<String, dynamic> toJson() => _$GetInfoResponseToJson(this);
}
