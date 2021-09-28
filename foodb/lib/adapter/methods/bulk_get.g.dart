// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_get.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BulkGetRequestDoc _$BulkGetRequestDocFromJson(Map<String, dynamic> json) {
  return BulkGetRequestDoc(
    id: json['id'] as String,
    rev: RevFromJsonString(json['rev'] as String?),
  );
}

Map<String, dynamic> _$BulkGetRequestDocToJson(BulkGetRequestDoc instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rev': RevToJsonString(instance.rev),
    };

BulkGetRequest _$BulkGetRequestFromJson(Map<String, dynamic> json) {
  return BulkGetRequest(
    docs: (json['docs'] as List<dynamic>)
        .map((e) => BulkGetRequestDoc.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$BulkGetRequestToJson(BulkGetRequest instance) =>
    <String, dynamic>{
      'docs': instance.docs.map((e) => e.toJson()).toList(),
    };

BulkGetResponse<T> _$BulkGetResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return BulkGetResponse<T>(
    results: (json['results'] as List<dynamic>)
        .map((e) => BulkGetIdDocs.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
  );
}

Map<String, dynamic> _$BulkGetResponseToJson<T>(
  BulkGetResponse<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'results': instance.results
          .map((e) => e.toJson(
                (value) => toJsonT(value),
              ))
          .toList(),
    };

BulkGetIdDocs<T> _$BulkGetIdDocsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return BulkGetIdDocs<T>(
    id: json['id'] as String,
    docs: (json['docs'] as List<dynamic>)
        .map((e) => BulkGetDoc.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
  );
}

Map<String, dynamic> _$BulkGetIdDocsToJson<T>(
  BulkGetIdDocs<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'id': instance.id,
      'docs': instance.docs
          .map((e) => e.toJson(
                (value) => toJsonT(value),
              ))
          .toList(),
    };

BulkGetDocError _$BulkGetDocErrorFromJson(Map<String, dynamic> json) {
  return BulkGetDocError(
    id: json['id'] as String,
    rev: json['rev'] as String,
    error: json['error'] as String,
    reason: json['reason'] as String,
  );
}

Map<String, dynamic> _$BulkGetDocErrorToJson(BulkGetDocError instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rev': instance.rev,
      'error': instance.error,
      'reason': instance.reason,
    };

BulkGetDoc<T> _$BulkGetDocFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return BulkGetDoc<T>(
    doc: json['ok'] == null
        ? null
        : Doc.fromJson(
            json['ok'] as Map<String, dynamic>, (value) => fromJsonT(value)),
    error: json['error'] == null
        ? null
        : BulkGetDocError.fromJson(json['error'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$BulkGetDocToJson<T>(
  BulkGetDoc<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'ok': instance.doc?.toJson(
        (value) => toJsonT(value),
      ),
      'error': instance.error?.toJson(),
    };

BulkGetRequestBody _$BulkGetRequestBodyFromJson(Map<String, dynamic> json) {
  return BulkGetRequestBody(
    docs: (json['docs'] as List<dynamic>)
        .map((e) => BulkGetRequest.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$BulkGetRequestBodyToJson(BulkGetRequestBody instance) =>
    <String, dynamic>{
      'docs': instance.docs.map((e) => e.toJson()).toList(),
    };

BulkGetRequest _$BulkGetRequestFromJson(Map<String, dynamic> json) {
  return BulkGetRequest(
    rev: RevFromJsonString(json['rev'] as String?),
    id: json['id'] as String,
  );
}

Map<String, dynamic> _$BulkGetRequestToJson(BulkGetRequest instance) =>
    <String, dynamic>{
      'rev': RevToJsonString(instance.rev),
      'id': instance.id,
    };
