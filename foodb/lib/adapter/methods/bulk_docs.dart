import 'package:foodb/adapter/methods/put.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bulk_docs.g.dart';

@JsonSerializable(explicitToJson: true)
class BulkDocResponse {
  List<PutResponse> putResponses;
  BulkDocResponse({required this.putResponses});

  factory BulkDocResponse.fromJson(Map<String, dynamic> json) =>
      _$BulkDocResponseFromJson(json);
  Map<String, dynamic> toJson() => _$BulkDocResponseToJson(this);
}
