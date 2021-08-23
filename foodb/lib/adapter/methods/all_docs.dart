import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'all_docs.g.dart';

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class GetAllDocs<T> {
  int offset;

  @JsonKey(name: 'total_rows')
  int totalRows;

  List<Row<T>> rows;

  @JsonKey(name: 'update_seq')
  String? updateSeq;

  GetAllDocs(
      {required this.offset,
      required this.totalRows,
      required this.rows,
      this.updateSeq});

  factory GetAllDocs.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$GetAllDocsFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$GetAllDocsToJson(this, toJsonT);
}

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class Row<T> {
  String id;
  String key;
  Value value;
  Doc<T>? doc;

  Row({required this.id, required this.key, required this.value, this.doc});
  factory Row.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$RowFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$RowToJson(this, toJsonT);
}

@JsonSerializable()
class Value {
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev rev;
  Value({required this.rev});

  factory Value.fromJson(Map<String, dynamic> json) => _$ValueFromJson(json);
  Map<String, dynamic> toJson() => _$ValueToJson(this);
}

@JsonSerializable()
class GetAllDocsRequest {
  bool conflicts;
  bool descending;

  @JsonKey(name: 'endkey')
  String? endKey;

  @JsonKey(name: 'endkey_docid')
  String? endKeyDocId;
  bool group;

  @JsonKey(name: 'group_level')
  int? groupLevel;

  @JsonKey(name: 'include_docs')
  bool includeDocs;

  bool attachments;

  @JsonKey(name: 'att_encoding_info')
  bool attEncodingInfo;

  @JsonKey(name: 'inclusive_end')
  bool inclusiveEnd;

  Object? key;
  List<Object>? keys;
  int? limit;
  bool? reduce;
  int? skip;
  bool sorted;
  bool stable;
  String? stale;
  @JsonKey(name: 'startkey')
  String? startKey;

  @JsonKey(name: 'startkey_docid')
  String? startKeyDocId;
  String? update;

  @JsonKey(name: 'update_seq')
  bool updateSeq;

  GetAllDocsRequest({
    this.conflicts = true,
    this.descending = false,
    this.endKey,
    this.endKeyDocId,
    this.group = false,
    this.groupLevel,
    this.includeDocs = false,
    this.attachments = false,
    this.attEncodingInfo = false,
    this.inclusiveEnd = true,
    this.key,
    this.keys,
    this.limit,
    this.reduce,
    this.skip,
    this.sorted = true,
    this.stable = false,
    this.stale,
    this.startKey,
    this.startKeyDocId,
    this.update,
    this.updateSeq = false,
  });
  factory GetAllDocsRequest.fromJson(Map<String, dynamic> json) =>
      _$GetAllDocsRequestFromJson(json);
  Map<String, dynamic> toJson() => _$GetAllDocsRequestToJson(this);
}
