import 'package:json_annotation/json_annotation.dart';

import 'package:foodb/common/doc.dart';

part 'all_docs.g.dart';

@JsonSerializable()
class GetAllDocs {
  int offset;

  @JsonKey(name: 'total_rows')
  int totalRows;

  List<Row?> rows;

  @JsonKey(name: 'update_seq')
  String? updateSeq;

  GetAllDocs(
      {required this.offset,
      required this.totalRows,
      required this.rows,
      this.updateSeq});

  factory GetAllDocs.fromJson(Map<String, dynamic> json) =>
      _$GetAllDocsFromJson(json);
  Map<String, dynamic> toJson() => _$GetAllDocsToJson(this);
}

@JsonSerializable()
class Row {
  String id;
  String key;
  Value value;
  Doc doc;

  Row(
      {required this.id,
      required this.key,
      required this.value,
      required this.doc});

  factory Row.fromJson(Map<String, dynamic> json) => _$RowFromJson(json);
  Map<String, dynamic> toJson() => _$RowToJson(this);
}

@JsonSerializable()
class Value {
  String rev;
  Value({required this.rev});

  factory Value.fromJson(Map<String, dynamic> json) => _$ValueFromJson(json);
  Map<String, dynamic> toJson() => _$ValueToJson(this);
}

@JsonSerializable()
class GetAllDocsRequest {
  bool conflicts;
  bool descending;
  Object? endKey;

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
  Object? startKey;

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
