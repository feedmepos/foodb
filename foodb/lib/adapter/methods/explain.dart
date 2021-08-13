import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'explain.g.dart';

@JsonSerializable(explicitToJson: true)
class ExplainResponse {
  @JsonKey(name: "dbname")
  String? dbName;
  Index index;
  Map<String, dynamic> selector;
  Opts opts;
  int limit;
  int skip;
  Object fields;
  Map<String, dynamic>? range;

  ExplainResponse({
    this.dbName,
    required this.index,
    required this.selector,
    required this.opts,
    required this.limit,
    required this.skip,
    required this.fields,
    this.range,
  });

  factory ExplainResponse.fromJson(Map<String, dynamic> json) =>
      _$ExplainResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ExplainResponseToJson(this);
}

@JsonSerializable()
class Index {
  String? ddoc;
  String name;
  String type;
  Object def;

  Index({
    this.ddoc,
    required this.name,
    required this.type,
    required this.def,
  });

  factory Index.fromJson(Map<String, dynamic> json) => _$IndexFromJson(json);
  Map<String, dynamic> toJson() => _$IndexToJson(this);
}

@JsonSerializable()
class Opts {
  @JsonKey(name: "use_index")
  List<String> useIndex;

  String bookmark;
  int limit;
  int skip;
  Object? sort;
  Object? fields;
  List<int> r;
  bool conflicts;

  Opts({
    required this.useIndex,
    required this.bookmark,
    required this.limit,
    required this.skip,
    this.sort,
    required this.fields,
    required this.r,
    required this.conflicts,
  });

  factory Opts.fromJson(Map<String, dynamic> json) => _$OptsFromJson(json);
  Map<String, dynamic> toJson() => _$OptsToJson(this);
}
