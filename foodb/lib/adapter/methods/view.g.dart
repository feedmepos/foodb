// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetViewResponse<T> _$GetViewResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return GetViewResponse<T>(
    offset: json['offset'] as int?,
    totalRows: json['total_rows'] as int,
    rows: (json['rows'] as List<dynamic>)
        .map((e) => ViewRow.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
    updateSeq: json['update_seq'] as String?,
  );
}

Map<String, dynamic> _$GetViewResponseToJson<T>(
  GetViewResponse<T> instance,
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

ViewRow<T> _$ViewRowFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return ViewRow<T>(
    id: json['id'] as String,
    key: json['key'],
    value: json['value'],
    doc: json['doc'] == null
        ? null
        : Doc.fromJson(
            json['doc'] as Map<String, dynamic>, (value) => fromJsonT(value)),
  );
}

Map<String, dynamic> _$ViewRowToJson<T>(
  ViewRow<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'value': instance.value,
      'doc': instance.doc?.toJson(
        (value) => toJsonT(value),
      ),
    };

GetViewRequest _$GetViewRequestFromJson(Map<String, dynamic> json) {
  return GetViewRequest(
    conflicts: json['conflicts'] as bool,
    descending: json['descending'] as bool,
    endkey: json['endkey'],
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
    update: json['update'] as String?,
    updateSeq: json['update_seq'] as bool,
  );
}

Map<String, dynamic> _$GetViewRequestToJson(GetViewRequest instance) =>
    <String, dynamic>{
      'conflicts': instance.conflicts,
      'descending': instance.descending,
      'endkey': instance.endkey,
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
      'update': instance.update,
      'update_seq': instance.updateSeq,
    };
