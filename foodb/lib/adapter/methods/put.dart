import 'package:json_annotation/json_annotation.dart';

part 'put.g.dart';

@JsonSerializable()
class PutResponse {
  bool ok;
  String id;
  String rev;

  PutResponse({required this.ok, required this.id, required this.rev});

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
