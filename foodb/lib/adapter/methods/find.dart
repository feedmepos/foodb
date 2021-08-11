import 'package:json_annotation/json_annotation.dart';

import 'package:foodb/common/doc.dart';

part 'find.g.dart';

@JsonSerializable()
class FindRequest {
  Map<String, dynamic> selector;
  int limit;
  int? skip;
  List<Object>? sort;
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

@JsonSerializable(genericArgumentFactories: true)
class FindResponse<T> {
  List<Doc<T>?> docs;

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
