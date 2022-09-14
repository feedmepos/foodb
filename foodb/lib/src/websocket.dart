part of 'package:foodb/foodb.dart';

class WebSocketFoodbServerException implements Exception {
  String error;
  String? reason;
  WebSocketFoodbServerException({required this.error, this.reason});

  @override
  String toString() =>
      'WebSocketFoodbServerException(error: $error, reason: $reason)';
}

class WebSocketResponse {
  final dynamic data;
  final int status;
  final String messageId;
  final String? type;
  late Stream? stream;
  WebSocketResponse({
    required this.data,
    required this.status,
    required this.messageId,
    required this.type,
  });

  void setStream(Stream newStream) {
    stream = newStream;
  }

  static WebSocketResponse fromJson(Map<String, dynamic> json) {
    return WebSocketResponse(
      data: json['data'],
      status: json['status'] ?? 500,
      messageId: json['messageId'],
      type: json['type'],
    );
  }
}

class _WebSocketFoodb extends Foodb {
  final String dbName;
  final Uri baseUri;
  late IOWebSocketChannel client;
  final int timeoutSeconds;
  Map<String, Completer> completers = {};
  _WebSocketFoodb({
    required this.dbName,
    required this.baseUri,
    this.timeoutSeconds = 60,
  }) : super(dbName: dbName) {
    client = IOWebSocketChannel.connect(baseUri);
    client.stream.listen((message) {
      _handleMessage(jsonDecode(message));
    });
  }
  Map<String, StreamController> streamControllers = {};

  _handleMessage(message) {
    final response = WebSocketResponse.fromJson(message);
    final messageId = message['messageId'];
    if (response.type == 'stream') {
      if (streamControllers[messageId] == null) {
        final streamController = StreamController();
        streamControllers[messageId] = streamController;
      }
      response.setStream(streamControllers[messageId]!.stream);
      completers[messageId]?.complete(response);
      streamControllers[messageId]!.sink.add(jsonEncode(response.data));
    } else {
      completers[messageId]?.complete(response);
    }
    completers.remove(messageId);
  }

  Uri getUri(String path) {
    return Uri.parse("${baseUri.toString()}/$dbName/$path");
  }

  String get dbUri {
    return this.getUri("").toString();
  }

  Uuid _uuid = Uuid();

  Future<WebSocketResponse> _send({
    required UriBuilder uriBuilder,
    required String method,
    bool hold = false,
    dynamic body,
  }) async {
    final messageId = _uuid.v1();
    client.sink.add(jsonEncode({
      'method': method,
      'url': uriBuilder.build().toString(),
      'messageId': messageId,
      'body': body,
      'type': hold ? 'stream' : 'normal'
    }));
    final completer = Completer();
    completers[messageId] = completer;
    Timer? timer;
    if (!hold) {
      timer = Timer(Duration(seconds: timeoutSeconds), () {
        completers.remove(messageId);
        completer.completeError(WebSocketFoodbServerException(
          error: 'timeout ${timeoutSeconds}s',
        ));
      });
    }
    WebSocketResponse result = await completer.future;
    timer?.cancel();
    if (result.status > 400) {
      throw WebSocketFoodbServerException(error: result.data['error']);
    }
    return result;
  }

  @override
  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_bulk_get')));
    uriBuilder.queryParameters = convertToParams({"revs": revs});
    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: body.toJson(),
    );
    if (response.status == 200) {
      return BulkGetResponse<T>.fromJson(
        response.data,
        (json) => fromJsonT(json as Map<String, dynamic>),
      );
    }
    throw AdapterException(error: "Invalid Status Code");
  }

  @override
  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse)? onComplete,
    Function(ChangeResult)? onResult,
    Function(Object?, StackTrace? stackTrace) onError = defaultOnError,
  }) {
    StreamSubscription? subscription;
    var streamedResponse = ChangesStream(onCancel: () {
      subscription?.cancel();
    });
    runZonedGuarded(() async {
      UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_changes')));
      uriBuilder.queryParameters = convertToParams(request.toJson());
      if (request.feed == ChangeFeed.normal) {
        var response = await _send(uriBuilder: uriBuilder, method: 'GET');
        var changeRes = ChangeResponse.fromJson(response.data);
        changeRes.results.forEach((element) => onResult?.call(element));
        onComplete?.call(changeRes);
      } else {
        var res =
            await _send(uriBuilder: uriBuilder, method: 'GET', hold: true);
        var streamedRes = res.stream;
        String cache = "";
        List<ChangeResult> _results = [];
        subscription = streamedRes?.listen((event) {
          if (request.feed == ChangeFeed.continuous) {
            if (event.trim() != '') cache += event.trim();
            var items =
                RegExp("^{\".*},?\n?\$", multiLine: true).allMatches(cache);
            if (items.isNotEmpty) {
              var parseSuccess = false;
              items.forEach((i) {
                try {
                  var json = jsonDecode(cache.substring(i.start, i.end).trim());
                  if (json['id'] != null) {
                    onResult?.call(ChangeResult.fromJson(json));
                    parseSuccess = true;
                  }
                } catch (err) {}
              });
              if (parseSuccess) {
                cache = '';
              }
            }
          } else {
            cache += event;
            if (event.contains('last_seq')) {
              Map<String, dynamic> map = jsonDecode(cache);
              ChangeResponse changeResponse =
                  new ChangeResponse(results: _results);
              map['results'].forEach((r) {
                final result = ChangeResult.fromJson(r);
                changeResponse.results.add(result);
                onResult?.call(result);
              });
              changeResponse.lastSeq = map['last_seq'];
              changeResponse.pending = map['pending'];
              onComplete?.call(changeResponse);
            }
          }
        }, onError: onError);
      }
    }, (e, s) {
      streamedResponse.cancel();
      onError(e, s);
    });

    return streamedResponse;
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() async {
    UriBuilder uriBuilder =
        UriBuilder.fromUri((this.getUri('_ensure_full_commit')));
    final response = await _send(uriBuilder: uriBuilder, method: 'POST');
    return EnsureFullCommitResponse.fromJson(response.data);
  }

  @override
  Future<Doc<T>?> get<T>(
      {required String id,
      bool attachments = false,
      bool attEncodingInfo = false,
      List<String>? attsSince,
      bool conflicts = false,
      bool deletedConflicts = false,
      bool latest = false,
      bool localSeq = false,
      bool meta = false,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri(id)));
    uriBuilder.queryParameters = convertToParams({
      'revs': revs,
      'conflicts': conflicts,
      'deleted_conflicts': deletedConflicts,
      'latest': latest,
      'local_seq': localSeq,
      'meta': meta,
      'att_encoding_info': attEncodingInfo,
      'attachments': attachments,
      'atts_since': attsSince,
      'rev': rev,
      'revs_info': revsInfo
    });
    final response = await _send(uriBuilder: uriBuilder, method: 'GET');
    return response.data.containsKey('_id')
        ? Doc<T>.fromJson(
            response.data, (json) => fromJsonT(json as Map<String, dynamic>))
        : null;
  }

  @override
  Future<GetInfoResponse> info() async {
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri(''));
    final response = await _send(uriBuilder: uriBuilder, method: 'GET');

    if (response.status != 200) {
      throw AdapterException(error: 'database not found');
    }
    return GetInfoResponse.fromJson(response.data);
  }

  @override
  Future<GetServerInfoResponse> serverInfo() async {
    UriBuilder uriBuilder =
        UriBuilder.fromUri(Uri.parse("${baseUri.toString()}/"));
    final response = await _send(uriBuilder: uriBuilder, method: 'GET');
    return GetServerInfoResponse.fromJson(response.data);
  }

  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(doc.id));
    Map<String, dynamic> param = {'new_edits': newEdits};
    if (doc.rev != null) param['rev'] = doc.rev!.toString();
    uriBuilder.queryParameters = convertToParams(param);

    Map<String, dynamic> newBody = doc.toJson((value) => value);

    if (!newEdits) {
      if (doc.rev == null) {
        throw new AdapterException(
            error: 'rev is required when newEdits is false');
      }
      if (doc.revisions != null) {
        newBody['_revisions'] = doc.revisions!.toJson();
      }
    }
    final response =
        await _send(uriBuilder: uriBuilder, method: 'PUT', body: newBody);
    final data = response.data;

    if (data['error'] != null) {
      throw AdapterException(error: data['error'], reason: data['reason']);
    }
    return PutResponse.fromJson(data);
  }

  @override
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(id));
    uriBuilder.queryParameters = convertToParams({'rev': rev.toString()});
    final response = await _send(uriBuilder: uriBuilder, method: 'DELETE');
    final data = response.data;
    if (data['error'] != null) {
      throw AdapterException(error: data['error'], reason: data['reason']);
    }
    return DeleteResponse.fromJson(data);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri('_revs_diff'));

    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: body.map((key, value) =>
          MapEntry(key, value.map((e) => e.toString()).toList())),
    );
    final data = response.data;

    if (data.isEmpty) {
      return {};
    }
    return data.map<String, RevsDiff>((k, v) {
      return MapEntry<String, RevsDiff>(k, RevsDiff.fromJson(v));
    });
  }

  @override
  Future<IndexResponse> createIndex(
      {required QueryViewOptionsDef index,
      String? ddoc,
      String? name,
      String type = 'json',
      bool? partitioned}) async {
    Map<String, dynamic> body = Map();
    body['type'] = type;
    body['index'] = index.toJson();
    if (partitioned != null) {
      body['partitioned'] = partitioned;
    }
    if (ddoc != null) {
      body['ddoc'] = ddoc;
    }
    if (name != null) {
      body['name'] = name;
    }
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri('_index'));
    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: body,
    );
    final data = response.data;

    return IndexResponse.fromJson(data);
  }

  @override
  Future<FindResponse<T>> find<T>(FindRequest findRequest,
      T Function(Map<String, dynamic> p1) fromJsonT) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri('_find'));

    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: body,
    );
    final data = response.data;

    return FindResponse.fromJson(
      data,
      (e) => fromJsonT(e as Map<String, dynamic>),
    );
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri('_explain'));

    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: body,
    );
    final data = response.data;
    return ExplainResponse.fromJson(data);
  }

  @override
  Future<DeleteIndexResponse> deleteIndex(
      {required String ddoc, required String name}) async {
    UriBuilder uriBuilder =
        new UriBuilder.fromUri(this.getUri('$ddoc/json/$name'));
    final response = await _send(uriBuilder: uriBuilder, method: "DELETE");
    return DeleteIndexResponse.fromJson(response.data);
  }

  @override
  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_all_docs')));
    return _view(uriBuilder, getViewRequest, fromJsonT);
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = true}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri('_bulk_docs'));
    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: {
        'new_edits': newEdits,
        'docs': body.map((e) {
          Map<String, dynamic> map = e.toJson((value) => value);
          return map;
        }).toList()
      },
    );

    if (response.status == 201) {
      List<PutResponse> putResponses = [];
      for (Map<String, dynamic> row in response.data) {
        putResponses.add(PutResponse.fromJson(row));
      }
      return BulkDocResponse(putResponses: putResponses);
    } else {
      throw AdapterException(
        error: 'Invalid status code',
        reason: response.data['reason'],
      );
    }
  }

  @override
  Future<bool> compact() async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_compact')));
    await _send(uriBuilder: uriBuilder, method: 'POST');
    return true;
  }

  @override
  Future<bool> destroy() async {
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri(''));
    await _send(uriBuilder: uriBuilder, method: 'DELETE');
    return true;
  }

  @override
  Future<bool> initDb() async {
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri(''));

    final response = await _send(uriBuilder: uriBuilder, method: 'HEAD');
    if (response.status == 404) {
      final response = await _send(uriBuilder: uriBuilder, method: 'PUT');
      final data = response.data;
      if (data['error'] != null) {
        throw new AdapterException(
          error: data['error'],
          reason: data['reason'],
        );
      }
      return true;
    } else {
      return true;
    }
  }

  @override
  Future<bool> revsLimit(int limit) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_revs_limit')));
    await _send(uriBuilder: uriBuilder, method: 'PUT', body: limit);
    return true;
  }

  Future<GetViewResponse<T>> _view<T>(
      UriBuilder uriBuilder,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var json = getViewRequest.toJson();
    json.remove('keys');
    if (json.containsKey('startkey'))
      json['startkey'] = jsonEncode(json['startkey']);
    if (json.containsKey('endkey')) json['endkey'] = jsonEncode(json['endkey']);
    uriBuilder.queryParameters = convertToParams(json);
    WebSocketResponse response;
    if (getViewRequest.keys == null) {
      response = await _send(uriBuilder: uriBuilder, method: 'GET');
    } else {
      Map<String, dynamic> map = Map();
      map['keys'] = getViewRequest.keys;
      response = await _send(
        uriBuilder: uriBuilder,
        body: map,
        method: 'POST',
      );
    }
    return GetViewResponse.fromJson(
        response.data, (json) => fromJsonT(json as Map<String, dynamic>));
  }

  @override
  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewId,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    UriBuilder uriBuilder =
        UriBuilder.fromUri((this.getUri('_design/$ddocId/_view/$viewId')));
    return _view(uriBuilder, getViewRequest, fromJsonT);
  }
}
