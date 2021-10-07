// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'find.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FindResponse<T> _$FindResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return FindResponse<T>(
    docs: (json['docs'] as List<dynamic>)
        .map((e) => Doc.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
    executionStats: json['execution_stats'] == null
        ? null
        : ExecutionStats.fromJson(
            json['execution_stats'] as Map<String, dynamic>),
    warning: json['warning'] as String?,
    bookmark: json['bookmark'] as String?,
  );
}

Map<String, dynamic> _$FindResponseToJson<T>(
  FindResponse<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'docs': instance.docs
          .map((e) => e.toJson(
                (value) => toJsonT(value),
              ))
          .toList(),
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
