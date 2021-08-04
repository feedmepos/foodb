import 'dart:async';
import 'dart:convert';
import 'package:foodb/adapter/adapter.dart';
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

ChangeResult _$ChangeResultFromJson(Map<String, dynamic> json) {
  return ChangeResult(
    id: json['id'] as String,
    seq: json['seq'] as String,
    deleted: json['deleted'].runtimeType == String
        ? json.containsKey('deleted')
            ? true
            : false
        : json['deleted'] as bool?,
    changes: (json['changes'].runtimeType == String
            ? jsonDecode(json['changes'])
            : json['changes'] as List<dynamic>)
        .map<ChangeResultRev>(
            (e) => ChangeResultRev.fromJson(e as Map<String, dynamic>))
        .toList(),
    doc: json['doc'].runtimeType == String
        ? jsonDecode(json['doc'])
        : json['doc'] as Map<String, dynamic>?,
  );
}

Map<String, dynamic> _$ChangeResultToJson(ChangeResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'seq': instance.seq,
      'deleted': instance.deleted,
      'changes': instance.changes,
      'doc': instance.doc,
    };

class ChangesStream {
  Stream<String> _stream;
  // Stream<String> get stream => _stream;
  Client _client;
  String _feed;
  List<ChangeResult> _results = [];
  ChangesStream({
    required stream,
    required client,
    required feed,
  })  : _stream = stream,
        _client = client,
        _feed = feed;
  List<StreamSubscription> subscriptions = [];

  cancel() {
    subscriptions.forEach((element) {
      element.cancel();
    });
    _client.close();
  }

  onHeartbeat(Function listener) {
    var subscription = _stream.listen((event) {
      print(event);
      if (event.trim() == '') {
        listener();
      }
    });
    subscriptions.add(subscription);
    return subscription;
  }

  onResult(Function(ChangeResult) listener) {
    var subscription = _stream.listen((event) {
      print(event);
      var splitted = event.split('\n').map((e) => e.trim());
      var changeResults =
          splitted.where((element) => RegExp("^{.*},?\$").hasMatch(element));
      changeResults.forEach((element) {
        var result = ChangeResult.fromJson(
            jsonDecode(element.replaceAll(RegExp(",\$"), "")));

        if (_feed != ChangeFeed.continuous) _results.add(result);
        listener(result);
      });
      // if (event is ChangeResult) {
      //   listener.call(event);
      // }
    });
    subscriptions.add(subscription);
    return subscription;
  }

  onComplete(Function(ChangeResponse) listener) {
    var subscription = _stream.listen((event) {
      var splitted = event.split('\n').map((e) => e.trim());
      splitted.forEach((element) {
        if (element.startsWith("\"last_seq\"")) {
          element = "{" + element;
          Map<String, dynamic> map = jsonDecode(element);
          ChangeResponse changeResponse = new ChangeResponse(results: _results);
          changeResponse.lastSeq = map['last_seq'];
          changeResponse.pending = map['pending'];
          listener(changeResponse);

          cancel();
        }
      });
    });
    subscriptions.add(subscription);
    return subscription;
  }
}

@JsonSerializable()
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

class ChangeRequest {
  ChangeRequestBody? body;
  bool conflicts;
  bool descending;
  String feed;
  String? filter;
  int heartbeat;
  bool includeDocs;
  bool attachments;
  bool attEncodingInfo;
  int? lastEventId;
  int? limit;
  String since;
  String style;
  int timeout;
  String? view;
  int? seqInterval;

  ChangeRequest({
    this.body,
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
}

@JsonSerializable()
class ChangeRequestBody {
  @JsonKey(name: 'doc_ids')
  List<String> docIds;

  ChangeRequestBody({required this.docIds});

  factory ChangeRequestBody.fromJson(Map<String, dynamic> json) =>
      _$ChangeRequestBodyFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeRequestBodyToJson(this);
}
