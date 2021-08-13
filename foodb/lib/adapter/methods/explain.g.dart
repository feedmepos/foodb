// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explain.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExplainResponse _$ExplainResponseFromJson(Map<String, dynamic> json) {
  return ExplainResponse(
    dbName: json['dbname'] as String?,
    index: Index.fromJson(json['index'] as Map<String, dynamic>),
    selector: json['selector'] as Map<String, dynamic>,
    opts: Opts.fromJson(json['opts'] as Map<String, dynamic>),
    limit: json['limit'] as int,
    skip: json['skip'] as int,
    fields: json['fields'] as Object,
    range: json['range'] as Map<String, dynamic>?,
  );
}

Map<String, dynamic> _$ExplainResponseToJson(ExplainResponse instance) =>
    <String, dynamic>{
      'dbname': instance.dbName,
      'index': instance.index.toJson(),
      'selector': instance.selector,
      'opts': instance.opts.toJson(),
      'limit': instance.limit,
      'skip': instance.skip,
      'fields': instance.fields,
      'range': instance.range,
    };

Index _$IndexFromJson(Map<String, dynamic> json) {
  return Index(
    ddoc: json['ddoc'] as String?,
    name: json['name'] as String,
    type: json['type'] as String,
    def: json['def'] as Object,
  );
}

Map<String, dynamic> _$IndexToJson(Index instance) => <String, dynamic>{
      'ddoc': instance.ddoc,
      'name': instance.name,
      'type': instance.type,
      'def': instance.def,
    };

Opts _$OptsFromJson(Map<String, dynamic> json) {
  return Opts(
    useIndex:
        (json['use_index'] as List<dynamic>).map((e) => e as String).toList(),
    bookmark: json['bookmark'] as String,
    limit: json['limit'] as int,
    skip: json['skip'] as int,
    sort: json['sort'],
    fields: json['fields'],
    r: (json['r'] as List<dynamic>).map((e) => e as int).toList(),
    conflicts: json['conflicts'] as bool,
  );
}

Map<String, dynamic> _$OptsToJson(Opts instance) => <String, dynamic>{
      'use_index': instance.useIndex,
      'bookmark': instance.bookmark,
      'limit': instance.limit,
      'skip': instance.skip,
      'sort': instance.sort,
      'fields': instance.fields,
      'r': instance.r,
      'conflicts': instance.conflicts,
    };
