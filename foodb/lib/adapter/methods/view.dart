import 'package:foodb/common/doc.dart';
import 'package:json_annotation/json_annotation.dart';

part 'view.g.dart';

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class GetViewResponse<T> {
  int? offset;

  @JsonKey(name: 'total_rows')
  int totalRows;

  List<ViewRow<T>> rows;

  @JsonKey(name: 'update_seq')
  String? updateSeq;

  GetViewResponse(
      {required this.offset,
      required this.totalRows,
      required this.rows,
      this.updateSeq});

  factory GetViewResponse.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$GetViewResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$GetViewResponseToJson(this, toJsonT);
}

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class ViewRow<T> {
  String id;
  dynamic key;
  dynamic value;
  Doc<T>? doc;

  ViewRow({required this.id, required this.key, this.value, this.doc});
  factory ViewRow.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$ViewRowFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ViewRowToJson(this, toJsonT);
}

@JsonSerializable()
class GetViewRequest {
  bool conflicts;
  bool descending;

  dynamic endkey;

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
  dynamic startkey;

  String? update;

  @JsonKey(name: 'update_seq')
  bool updateSeq;

  GetViewRequest({
    this.conflicts = false,
    this.descending = false,
    this.endkey,
    this.group = false,
    this.groupLevel,
    this.includeDocs = false,
    this.attachments = false,
    this.attEncodingInfo = false,
    this.inclusiveEnd = true,
    this.key,
    this.keys,
    this.limit,
    this.reduce = false,
    this.skip,
    this.sorted = true,
    this.stable = false,
    this.stale,
    this.startkey,
    this.update,
    this.updateSeq = false,
  });
  factory GetViewRequest.fromJson(Map<String, dynamic> json) =>
      _$GetViewRequestFromJson(json);
  Map<String, dynamic> toJson() => _$GetViewRequestToJson(this);
}
