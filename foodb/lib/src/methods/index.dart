import 'package:json_annotation/json_annotation.dart';

part 'index.g.dart';

@JsonSerializable()
class IndexResponse {
  String result;
  String id;
  String name;

  IndexResponse({required this.result, required this.id, required this.name});

  factory IndexResponse.fromJson(Map<String, dynamic> json) =>
      _$IndexResponseFromJson(json);
  Map<String, dynamic> toJson() => _$IndexResponseToJson(this);
}

@JsonSerializable()
class DeleteIndexResponse {
  bool ok;

  DeleteIndexResponse({required this.ok});

  factory DeleteIndexResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteIndexResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DeleteIndexResponseToJson(this);
}
