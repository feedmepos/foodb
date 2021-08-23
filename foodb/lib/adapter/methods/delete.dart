import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'delete.g.dart';

@JsonSerializable()
class DeleteResponse {
  bool? ok;
  String? id;
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev? rev;
  String? error;
  String? reason;

  DeleteResponse({this.ok, this.id, this.rev, this.error, this.reason});

  factory DeleteResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DeleteResponseToJson(this);
}
