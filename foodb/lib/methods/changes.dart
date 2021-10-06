import 'dart:async';
import 'dart:convert';
import 'package:foodb/foodb.dart';
import 'package:json_annotation/json_annotation.dart';

part 'changes.g.dart';

class ChangeFeed {
  static final continuous = "continuous";
  static final longpoll = "longpoll";
  static final normal = "normal";
}

@JsonSerializable()
class ChangeResultRev {
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev rev;

  ChangeResultRev({required this.rev});

  factory ChangeResultRev.fromJson(Map<String, dynamic> json) =>
      _$ChangeResultRevFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeResultRevToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ChangeResult {
  String id;
  String? seq;
  bool? deleted;
  List<ChangeResultRev> changes;
  Doc<Map<String, dynamic>>? doc;

  ChangeResult({
    required this.id,
    this.seq,
    this.deleted,
    required this.changes,
    this.doc,
  });

  factory ChangeResult.fromJson(Map<String, dynamic> json) =>
      _$ChangeResultFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeResultToJson(this);
}

class ChangesStream {
  Function? _onCancel;
  ChangesStream({onCancel}) : _onCancel = onCancel;

  cancel() async {
    _onCancel?.call();
  }
}

@JsonSerializable(explicitToJson: true)
class ChangeResponse {
  @JsonKey(name: 'last_seq')
  String? lastSeq;
  int? pending;
  List<ChangeResult> results;

  ChangeResponse({
    this.lastSeq,
    this.pending,
    required this.results,
  });

  factory ChangeResponse.fromJson(Map<String, dynamic> json) =>
      _$ChangeResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ChangeRequest {
  @JsonKey(name: 'doc_ids')
  List<String>? docIds;
  bool conflicts;
  bool descending;
  String feed;
  String? filter;
  int heartbeat;

  @JsonKey(name: "include_docs")
  bool includeDocs;
  bool attachments;

  @JsonKey(name: "att_encoding_info")
  bool attEncodingInfo;

  @JsonKey(name: "last_event_id")
  int? lastEventId;

  int? limit;
  String since;
  String style;
  int timeout;
  String? view;

  @JsonKey(name: "seq_interval")
  int? seqInterval;

  ChangeRequest({
    this.docIds,
    this.conflicts = false,
    this.descending = false,
    this.feed = 'normal',
    this.filter,
    this.heartbeat = 30000,
    this.includeDocs = false,
    this.attachments = false,
    this.attEncodingInfo = false,
    this.lastEventId,
    this.limit,
    this.since = '0',
    this.style = 'main_only',
    this.timeout = 30000,
    this.view,
    this.seqInterval,
  });

  factory ChangeRequest.fromJson(Map<String, dynamic> json) =>
      _$ChangeRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeRequestToJson(this);
}
