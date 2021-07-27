import 'package:foodb/adapter/methods/put.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bulk_docs.g.dart';

@JsonSerializable()
class BulkDocResponse {
  List<PutResponse>? putResponses;
  String? error;
  String? reason;
  BulkDocResponse({this.putResponses, this.error, this.reason});

  factory BulkDocResponse.fromJson(Map<String, dynamic> json) =>
      _$BulkDocResponseFromJson(json);
  Map<String, dynamic> toJson() => _$BulkDocResponseToJson(this);
}
