// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'find.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FindRequest _$FindRequestFromJson(Map<String, dynamic> json) {
  return FindRequest(
    selector: json['selector'] as Object,
    limit: json['limit'] as int,
    skip: json['skip'] as int?,
    sort: (json['sort'] as List<dynamic>?)?.map((e) => e as Object).toList(),
    fields:
        (json['fields'] as List<dynamic>?)?.map((e) => e as String).toList(),
    useIndex: json['use_index'],
    conflicts: json['conflicts'] as bool,
    r: json['r'] as int,
    bookmark: json['bookmark'] as String?,
    update: json['update'] as bool,
    stable: json['stable'] as bool?,
    stale: json['stale'] as String,
    executionStats: json['execution_stats'] as bool,
  );
}

Map<String, dynamic> _$FindRequestToJson(FindRequest instance) =>
    <String, dynamic>{
      'selector': instance.selector,
      'limit': instance.limit,
      'skip': instance.skip,
      'sort': instance.sort,
      'fields': instance.fields,
      'use_index': instance.useIndex,
      'conflicts': instance.conflicts,
      'r': instance.r,
      'bookmark': instance.bookmark,
      'update': instance.update,
      'stable': instance.stable,
      'stale': instance.stale,
      'execution_stats': instance.executionStats,
    };

FindResponse _$FindResponseFromJson(Map<String, dynamic> json) {
  return FindResponse(
    docs: (json['docs'] as List<dynamic>)
        .map((e) => e == null ? null : Doc.fromJson(e as Map<String, dynamic>))
        .toList(),
    executionStats: json['execution_stats'] == null
        ? null
        : ExecutionStats.fromJson(
            json['execution_stats'] as Map<String, dynamic>),
    warning: json['warning'] as String?,
    bookmark: json['bookmark'] as String?,
  );
}

Map<String, dynamic> _$FindResponseToJson(FindResponse instance) =>
    <String, dynamic>{
      'docs': instance.docs,
      'execution_stats': instance.executionStats,
      'warning': instance.warning,
      'bookmark': instance.bookmark,
    };

ExecutionStats _$ExecutionStatsFromJson(Map<String, dynamic> json) {
  return ExecutionStats(
    totalKeysExamined: json['total_keys_examined'] as int,
    totalDocsExamined: json['total_docs_examined'] as int,
    totalQuorumDocsExamined: json['total_quorum_docs_examined'] as int,
    resultsReturned: json['results_returned'] as int,
    executionTimeMs: json['execution_time_ms'] as int,
  );
}

Map<String, dynamic> _$ExecutionStatsToJson(ExecutionStats instance) =>
    <String, dynamic>{
      'total_keys_examined': instance.totalKeysExamined,
      'total_docs_examined': instance.totalDocsExamined,
      'total_quorum_docs_examined': instance.totalQuorumDocsExamined,
      'results_returned': instance.resultsReturned,
      'execution_time_ms': instance.executionTimeMs,
    };
