import 'package:foodb/selector.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:foodb/foodb.dart';
part 'find.g.dart';

class FindRequest {
  Operator selector;
  int? limit;
  int? skip;
  List<Map<String, String>>? sort;
  List<String>? fields;

  @JsonKey(name: 'use_index')
  Object? useIndex;

  bool conflicts;
  int r;
  String? bookmark;
  bool update;
  bool? stable;
  String stale;

  @JsonKey(name: 'execution_stats')
  bool executionStats;

  FindRequest(
      {required this.selector,
      this.limit = 25,
      this.skip,
      this.sort,
      this.fields,
      this.useIndex,
      this.conflicts = false,
      this.r = 1,
      this.bookmark,
      this.update = true,
      this.stable,
      this.stale = 'false',
      this.executionStats = false});

  factory FindRequest.fromJson(Map<String, dynamic> json) =>
      _$FindRequestFromJson(json);
  Map<String, dynamic> toJson() => _$FindRequestToJson(this);
}

FindRequest _$FindRequestFromJson(Map<String, dynamic> json) {
  return FindRequest(
    selector: SelectorBuilder().fromJson(json['selector']),
    limit: json['limit'] as int?,
    skip: json['skip'] as int?,
    sort: (json['sort'] as List<dynamic>?)
        ?.map((e) => Map<String, String>.from(e as Map))
        .toList(),
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
      'selector': instance.selector.toJson(),
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



@JsonSerializable(genericArgumentFactories: true)
class FindResponse<T> {
  List<Doc<T>> docs;

  @JsonKey(name: 'execution_stats')
  ExecutionStats? executionStats;

  String? warning;
  String? bookmark;

  FindResponse(
      {required this.docs, this.executionStats, this.warning, this.bookmark});

  factory FindResponse.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$FindResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$FindResponseToJson(this, toJsonT);
}

@JsonSerializable()
class ExecutionStats {
  @JsonKey(name: 'total_keys_examined')
  int totalKeysExamined;

  @JsonKey(name: 'total_docs_examined')
  int totalDocsExamined;

  @JsonKey(name: 'total_quorum_docs_examined')
  int totalQuorumDocsExamined;

  @JsonKey(name: 'results_returned')
  int resultsReturned;

  @JsonKey(name: 'execution_time_ms')
  int executionTimeMs;

  ExecutionStats({
    required this.totalKeysExamined,
    required this.totalDocsExamined,
    required this.totalQuorumDocsExamined,
    required this.resultsReturned,
    required this.executionTimeMs,
  });

  factory ExecutionStats.fromJson(Map<String, dynamic> json) =>
      _$ExecutionStatsFromJson(json);
  Map<String, dynamic> toJson() => _$ExecutionStatsToJson(this);
}
