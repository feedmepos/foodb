import 'package:json_annotation/json_annotation.dart';

part 'put.g.dart';

@JsonSerializable()
class PutResponse {
  bool? ok;
  String? id;
  String? rev;
  String? error;
  String? reason;

  PutResponse({this.ok, this.id, this.rev, this.error, this.reason});

  factory PutResponse.fromJson(Map<String, dynamic> json) =>
      _$PutResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PutResponseToJson(this);
}

@JsonSerializable()
class PutRequestBody {
  String? rev;
  PutRequestBody({
    this.rev,
  });

  factory PutRequestBody.fromJson(Map<String, dynamic> json) =>
      _$PutRequestBodyFromJson(json);
  Map<String, dynamic> toJson() => _$PutRequestBodyToJson(this);
}
