import 'package:json_annotation/json_annotation.dart';

part 'ensure_full_commit.g.dart';

@JsonSerializable()
class EnsureFullCommitResponse {
  @JsonKey(name: 'instance_start_time')
  String instanceStartTime;
  bool ok;
  EnsureFullCommitResponse({
    required this.instanceStartTime,
    required this.ok,
  });

  factory EnsureFullCommitResponse.fromJson(Map<String, dynamic> json) =>
      _$EnsureFullCommitResponseFromJson(json);
  Map<String, dynamic> toJson() => _$EnsureFullCommitResponseToJson(this);
}
