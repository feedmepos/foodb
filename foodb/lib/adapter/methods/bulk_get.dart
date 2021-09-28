import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bulk_get.g.dart';

@JsonSerializable()
class BulkGetRequestDoc {
  final String id;
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  final Rev? rev;
  BulkGetRequestDoc({
    required this.id,
    this.rev,
  });

  factory BulkGetRequestDoc.fromJson(Map<String, dynamic> json) =>
      _$BulkGetRequestDocFromJson(json);
  Map<String, dynamic> toJson() => _$BulkGetRequestDocToJson(this);
}

@JsonSerializable(explicitToJson: true)
class BulkGetRequest {
  final List<BulkGetRequestDoc> docs;

  BulkGetRequest({
    required this.docs,
  });

  factory BulkGetRequest.fromJson(Map<String, dynamic> json) =>
      _$BulkGetRequestFromJson(json);
  Map<String, dynamic> toJson() => _$BulkGetRequestToJson(this);
}

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class BulkGetResponse<T> {
  final List<BulkGetIdDocs<T>> results;

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
  final String id;
  final List<BulkGetDoc<T>> docs;

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

@JsonSerializable()
class BulkGetDocError {
  final String id;
  final String rev;
  final String error;
  final String reason;
  BulkGetDocError({
    required this.id,
    required this.rev,
    required this.error,
    required this.reason,
  });

  factory BulkGetDocError.fromJson(Map<String, dynamic> json) =>
      _$BulkGetDocErrorFromJson(json);
  Map<String, dynamic> toJson() => _$BulkGetDocErrorToJson(this);
}

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class BulkGetDoc<T> {
  @JsonKey(name: "ok")
  final Doc<T>? doc;

  @JsonKey(name: 'error')
  final BulkGetDocError? error;

  BulkGetDoc({
    this.doc,
    this.error,
  });

  factory BulkGetDoc.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$BulkGetDocFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$BulkGetDocToJson(this, toJsonT);
}
