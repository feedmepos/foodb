// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all_docs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAllDocs<T> _$GetAllDocsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return GetAllDocs<T>(
    offset: json['offset'] as int,
    totalRows: json['total_rows'] as int,
    rows: (json['rows'] as List<dynamic>)
        .map((e) => Row.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
    updateSeq: json['update_seq'] as String?,
  );
}

Map<String, dynamic> _$GetAllDocsToJson<T>(
  GetAllDocs<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'offset': instance.offset,
      'total_rows': instance.totalRows,
      'rows': instance.rows
          .map((e) => e.toJson(
                (value) => toJsonT(value),
              ))
          .toList(),
      'update_seq': instance.updateSeq,
    };

Row<T> _$RowFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return Row<T>(
    id: json['id'] as String,
    key: json['key'] as String,
    value: Value.fromJson(json['value'] as Map<String, dynamic>),
    doc: json['doc'] == null
        ? null
        : Doc.fromJson(
            json['doc'] as Map<String, dynamic>, (value) => fromJsonT(value)),
  );
}

Map<String, dynamic> _$RowToJson<T>(
  Row<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'value': instance.value.toJson(),
      'doc': instance.doc?.toJson(
        (value) => toJsonT(value),
      ),
    };

Value _$ValueFromJson(Map<String, dynamic> json) {
  return Value(
    rev: json['rev'] as String,
  );
}

Map<String, dynamic> _$ValueToJson(Value instance) => <String, dynamic>{
      'rev': instance.rev,
    };

GetAllDocsRequest _$GetAllDocsRequestFromJson(Map<String, dynamic> json) {
  return GetAllDocsRequest(
    conflicts: json['conflicts'] as bool,
    descending: json['descending'] as bool,
    endKey: json['endkey'] as String?,
    endKeyDocId: json['endkey_docid'] as String?,
    group: json['group'] as bool,
    groupLevel: json['group_level'] as int?,
    includeDocs: json['include_docs'] as bool,
    attachments: json['attachments'] as bool,
    attEncodingInfo: json['att_encoding_info'] as bool,
    inclusiveEnd: json['inclusive_end'] as bool,
    key: json['key'],
    keys: (json['keys'] as List<dynamic>?)?.map((e) => e as Object).toList(),
    limit: json['limit'] as int?,
    reduce: json['reduce'] as bool?,
    skip: json['skip'] as int?,
    sorted: json['sorted'] as bool,
    stable: json['stable'] as bool,
    stale: json['stale'] as String?,
    startKey: json['startkey'] as String?,
    startKeyDocId: json['startkey_docid'] as String?,
    update: json['update'] as String?,
    updateSeq: json['update_seq'] as bool,
  );
}

Map<String, dynamic> _$GetAllDocsRequestToJson(GetAllDocsRequest instance) =>
    <String, dynamic>{
      'conflicts': instance.conflicts,
      'descending': instance.descending,
      'endkey': instance.endKey,
      'endkey_docid': instance.endKeyDocId,
      'group': instance.group,
      'group_level': instance.groupLevel,
      'include_docs': instance.includeDocs,
      'attachments': instance.attachments,
      'att_encoding_info': instance.attEncodingInfo,
      'inclusive_end': instance.inclusiveEnd,
      'key': instance.key,
      'keys': instance.keys,
      'limit': instance.limit,
      'reduce': instance.reduce,
      'skip': instance.skip,
      'sorted': instance.sorted,
      'stable': instance.stable,
      'stale': instance.stale,
      'startkey': instance.startKey,
      'startkey_docid': instance.startKeyDocId,
      'update': instance.update,
      'update_seq': instance.updateSeq,
    };
