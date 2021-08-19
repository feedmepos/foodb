import 'dart:async';
import 'dart:convert';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/common/doc.dart';
import 'package:http/http.dart';
import 'package:json_annotation/json_annotation.dart';

part 'changes.g.dart';

@JsonSerializable()
class ChangeResultRev {
  String rev;

  ChangeResultRev({required this.rev});

  factory ChangeResultRev.fromJson(Map<String, dynamic> json) =>
      _$ChangeResultRevFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeResultRevToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ChangeResult {
  String id;
  String seq;
  bool? deleted;
  List<ChangeResultRev> changes;
  Map<String, dynamic>? doc;

  ChangeResult({
    required this.id,
    required this.seq,
    this.deleted,
    required this.changes,
    this.doc,
  });

  factory ChangeResult.fromJson(Map<String, dynamic> json) =>
      _$ChangeResultFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeResultToJson(this);
}

class ChangesStream {
  Stream<String> _stream;
  //Client? _client;
  String _feed;
  Function? _onCancel;
  List<ChangeResult> _results = [];
  StreamSubscription? _subscription;
  ChangesStream({required stream, required feed, onCancel})
      : _stream = stream,
        // _client = client,
        _onCancel = onCancel,
        _feed = feed;

  cancel() async {
    if (_onCancel != null) await _onCancel!();
    if (_subscription != null) await _subscription!.cancel();
    //if (_client != null) _client!.close();
  }

  void listen(
      {Function(ChangeResponse)? onComplete,
      Function(ChangeResult)? onResult,
      Function? onHearbeat}) {
    _subscription = _stream.listen((event) {
      // is heartbeat
      if (event.trim() == '') {
        if (onHearbeat != null) onHearbeat();
      }

      var splitted = event.split('\n').map((e) => e.trim());
      // is result
      var changeResults =
          splitted.where((element) => RegExp("^{.*},?\$").hasMatch(element));
      changeResults.forEach((element) {
        var result = ChangeResult.fromJson(
            jsonDecode(element.replaceAll(RegExp(",\$"), "")));

        if (_feed != ChangeFeed.continuous) _results.add(result);
        if (onResult != null) onResult(result);
      });

      // is completed
      splitted.forEach((element) {
        if (element.startsWith("\"last_seq\"")) {
          element = "{" + element;
          Map<String, dynamic> map = jsonDecode(element);
          ChangeResponse changeResponse = new ChangeResponse(results: _results);
          changeResponse.lastSeq = map['last_seq'];
          changeResponse.pending = map['pending'];
          if (onComplete != null) onComplete(changeResponse);
        }
      });
    });
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

@JsonSerializable()
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
    this.heartbeat = 60000,
    this.includeDocs = false,
    this.attachments = false,
    this.attEncodingInfo = false,
    this.lastEventId,
    this.limit,
    this.since = '0',
    this.style = 'main_only',
    this.timeout = 60000,
    this.view,
    this.seqInterval,
  });

  factory ChangeRequest.fromJson(Map<String, dynamic> json) =>
      _$ChangeRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeRequestToJson(this);
}
