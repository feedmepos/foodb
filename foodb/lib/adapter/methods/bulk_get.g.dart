// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_get.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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

BulkGetDoc<T> _$BulkGetDocFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return BulkGetDoc<T>(
    doc: json['ok'] == null
        ? null
        : Doc.fromJson(
            json['ok'] as Map<String, dynamic>, (value) => fromJsonT(value)),
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
    };
