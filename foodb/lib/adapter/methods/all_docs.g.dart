// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all_docs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAllDocsResponse<T> _$GetAllDocsResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return GetAllDocsResponse<T>(
    offset: json['offset'] as int?,
    totalRows: json['total_rows'] as int,
    rows: (json['rows'] as List<dynamic>)
        .map((e) => AllDocRow.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
    updateSeq: json['update_seq'] as String?,
  );
}

Map<String, dynamic> _$GetAllDocsResponseToJson<T>(
  GetAllDocsResponse<T> instance,
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

AllDocRow<T> _$AllDocRowFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return AllDocRow<T>(
    id: json['id'] as String,
    key: json['key'] as String,
    value: AllDocRowValue.fromJson(json['value'] as Map<String, dynamic>),
    doc: json['doc'] == null
        ? null
        : Doc.fromJson(
            json['doc'] as Map<String, dynamic>, (value) => fromJsonT(value)),
  );
}

Map<String, dynamic> _$AllDocRowToJson<T>(
  AllDocRow<T> instance,
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

AllDocRowValue _$AllDocRowValueFromJson(Map<String, dynamic> json) {
  return AllDocRowValue(
    rev: RevFromJsonString(json['rev'] as String?),
  );
}

Map<String, dynamic> _$AllDocRowValueToJson(AllDocRowValue instance) =>
    <String, dynamic>{
      'rev': RevToJsonString(instance.rev),
    };

GetAllDocsRequest _$GetAllDocsRequestFromJson(Map<String, dynamic> json) {
  return GetAllDocsRequest(
    conflicts: json['conflicts'] as bool,
    descending: json['descending'] as bool,
    endkey: json['endkey'],
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
    startkey: json['startkey'],
    startKeyDocId: json['startkey_docid'] as String?,
    update: json['update'] as String?,
    updateSeq: json['update_seq'] as bool,
  );
}

Map<String, dynamic> _$GetAllDocsRequestToJson(GetAllDocsRequest instance) =>
    <String, dynamic>{
      'conflicts': instance.conflicts,
      'descending': instance.descending,
      'endkey': instance.endkey,
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
      'startkey': instance.startkey,
      'startkey_docid': instance.startKeyDocId,
      'update': instance.update,
      'update_seq': instance.updateSeq,
    };
