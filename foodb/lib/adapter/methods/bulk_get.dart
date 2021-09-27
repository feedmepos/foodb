import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bulk_get.g.dart';

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class BulkGetResponse<T> {
  List<BulkGetIdDocs<T>> results;

  BulkGetResponse({
    required this.results,
  });

  factory BulkGetResponse.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$BulkGetResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$BulkGetResponseToJson(this, toJsonT);
}

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class BulkGetIdDocs<T> {
  String id;
  List<BulkGetDoc<T>> docs;

  BulkGetIdDocs({
    required this.id,
    required this.docs,
  });

  factory BulkGetIdDocs.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$BulkGetIdDocsFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$BulkGetIdDocsToJson(this, toJsonT);
}

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class BulkGetDoc<T> {
  @JsonKey(name: "ok")
  Doc<T>? doc;

  BulkGetDoc({
    required this.doc,
  });

  factory BulkGetDoc.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$BulkGetDocFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$BulkGetDocToJson(this, toJsonT);
}

@JsonSerializable(explicitToJson: true)
class BulkGetRequestBody {
  List<BulkGetRequest> docs;

  BulkGetRequestBody({
    required this.docs,
  });

  factory BulkGetRequestBody.fromJson(Map<String, dynamic> json) =>
      _$BulkGetRequestBodyFromJson(json);
  Map<String, dynamic> toJson() => _$BulkGetRequestBodyToJson(this);
}

@JsonSerializable()
class BulkGetRequest {
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev rev;
  String id;

  BulkGetRequest({
    required this.rev,
    required this.id,
  });

  factory BulkGetRequest.fromJson(Map<String, dynamic> json) =>
      _$BulkGetRequestFromJson(json);
  Map<String, dynamic> toJson() => _$BulkGetRequestToJson(this);
}
