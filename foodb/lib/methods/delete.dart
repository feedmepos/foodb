import 'package:foodb/foodb.dart';
import 'package:json_annotation/json_annotation.dart';

part 'delete.g.dart';

@JsonSerializable()
class DeleteResponse {
  bool ok;
  String id;
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev rev;

  DeleteResponse({required this.ok, required this.id, required this.rev});

  factory DeleteResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DeleteResponseToJson(this);
}
