part of 'package:foodb/foodb.dart';

class _WebSocketFoodb extends Foodb {
  final String dbName;
  final Uri baseUri;
  final bool mock;
  late MockableIOWebSocketChannel client;
  Map<String, Completer> completers = {};
  _WebSocketFoodb({
    required this.dbName,
    required this.baseUri,
    this.mock = false,
  }) : super(dbName: dbName) {
    client = MockableIOWebSocketChannel(url: baseUri, mock: mock);
    client.listen((message) {
      _handleMessage(message);
    });
  }

  _handleMessage(message) {
    final messageId = message['messageId'];
    completers[messageId]?.complete(message);
    completers.remove(messageId);
  }

  Uri getUri(String path) {
    return Uri.parse("${baseUri.toString()}/$dbName/$path");
  }

  String get dbUri {
    return this.getUri("").toString();
  }

  Uuid _uuid = Uuid();

  _send({
    required UriBuilder uriBuilder,
    required String method,
    String? body,
  }) async {
    final messageId = _uuid.v1();
    client.add({
      'method': method,
      'url': uriBuilder.build().toString(),
      'messageId': messageId,
      'body': body,
    });
    final completer = Completer();
    completers[messageId] = completer;
    final result = await completer.future;
    final seconds = 10;
    Future.delayed(Duration(seconds: seconds), () {
      completers.remove(messageId);
      throw Exception('timeout ${seconds}s');
    });
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
      body: jsonEncode(body.toJson()),
    );
    if (response.statusCode == 200) {
      return BulkGetResponse<T>.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
          (json) => fromJsonT(json as Map<String, dynamic>));
    }
    throw AdapterException(error: "Invalid Status Code");
  }

  @override
  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse p1)? onComplete,
    Function(ChangeResult p1)? onResult,
    Function(Object? p1, StackTrace? stackTrace) onError = defaultOnError,
  }) {
    StreamSubscription? subscription;
    var streamedResponse = ChangesStream(onCancel: () {
      subscription?.cancel();
    });
    runZonedGuarded(() async {
      UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_changes')));
      uriBuilder.queryParameters = convertToParams(request.toJson());
      if (request.feed == ChangeFeed.normal) {
        var res = await _send(uriBuilder: uriBuilder, method: 'GET');
        var changeRes = ChangeResponse.fromJson(jsonDecode(res.body));
        changeRes.results.forEach((element) => onResult?.call(element));
        onComplete?.call(changeRes);
      } else {
        var res = await _send(uriBuilder: uriBuilder, method: 'GET');
        var streamedRes = res.stream.transform(utf8.decoder);
        String cache = "";
        List<ChangeResult> _results = [];
        subscription = streamedRes.listen((event) {
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
    final result = await _send(uriBuilder: uriBuilder, method: 'POST');
    return EnsureFullCommitResponse.fromJson(
      jsonDecode(
        utf8.decode(
          result.bodyBytes,
        ),
      ),
    );
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
    final result = await _send(uriBuilder: uriBuilder, method: 'GET');
    return result.containsKey('_id')
        ? Doc<T>.fromJson(
            result, (json) => fromJsonT(json as Map<String, dynamic>))
        : null;
  }

  @override
  Future<GetInfoResponse> info() async {
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri(''));
    final response = await _send(uriBuilder: uriBuilder, method: 'GET');

    if (response.statusCode != 200) {
      throw AdapterException(error: 'database not found');
    }
    return GetInfoResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)));
  }

  @override
  Future<GetServerInfoResponse> serverInfo() async {
    UriBuilder uriBuilder =
        UriBuilder.fromUri(Uri.parse("${baseUri.toString()}/"));
    final result = await _send(uriBuilder: uriBuilder, method: 'GET');
    return GetServerInfoResponse.fromJson(
        jsonDecode(utf8.decode(result.bodyBytes)));
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
    final responseBody = await _send(
        uriBuilder: uriBuilder, method: 'PUT', body: jsonEncode(newBody));

    if (responseBody['error'] != null) {
      throw AdapterException(
          error: responseBody['error'], reason: responseBody['reason']);
    }
    return PutResponse.fromJson(responseBody);
  }

  @override
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(id));
    uriBuilder.queryParameters = convertToParams({'rev': rev.toString()});
    final result = await _send(uriBuilder: uriBuilder, method: 'DELETE');
    if (result['error'] != null) {
      throw AdapterException(error: result['error'], reason: result['reason']);
    }
    return DeleteResponse.fromJson(result);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri('_revs_diff'));

    final response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: jsonEncode(body.map((key, value) =>
          MapEntry(key, value.map((e) => e.toString()).toList()))),
    );
    Map<String, dynamic> decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded.isEmpty) {
      return {};
    }
    return decoded.map<String, RevsDiff>((k, v) {
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
    final result = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: jsonEncode(body),
    );
    var response = (jsonDecode(utf8.decode(result.bodyBytes)));

    return IndexResponse.fromJson(response);
  }

  @override
  Future<FindResponse<T>> find<T>(FindRequest findRequest,
      T Function(Map<String, dynamic> p1) fromJsonT) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri('_find'));

    var response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: jsonEncode(body),
    );

    return FindResponse.fromJson(
        jsonDecode(response), (e) => fromJsonT(e as Map<String, dynamic>));
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri('_explain'));

    var response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: jsonEncode(body),
    );
    return ExplainResponse.fromJson(response);
  }

  @override
  Future<DeleteIndexResponse> deleteIndex(
      {required String ddoc, required String name}) async {
    UriBuilder uriBuilder =
        new UriBuilder.fromUri(this.getUri('$ddoc/json/$name'));
    return await _send(uriBuilder: uriBuilder, method: "DELETE");
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
    UriBuilder uriBuilder = UriBuilder.fromUri(this.getUri(''));

    var response = await _send(
      uriBuilder: uriBuilder,
      method: 'POST',
      body: jsonEncode({
        'new_edits': newEdits,
        'docs': body.map((e) {
          Map<String, dynamic> map = e.toJson((value) => value);
          return map;
        }).toList()
      }),
    );

    if (response.statusCode == 201) {
      List<dynamic> responses = jsonDecode(utf8.decode(response.bodyBytes));
      List<PutResponse> putResponses = [];
      for (Map<String, dynamic> row in responses) {
        putResponses.add(PutResponse.fromJson(row));
      }
      return BulkDocResponse(putResponses: putResponses);
    } else {
      throw AdapterException(
          error: 'Invalid status code', reason: response.statusCode.toString());
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
    if (response.statusCode == 404) {
      final response = await _send(uriBuilder: uriBuilder, method: 'PUT');
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body['error'] != null) {
        throw new AdapterException(
            error: body['error'], reason: body['reason']);
      }
      return true;
    } else {
      return true;
    }
  }

  @override
  Future<bool> revsLimit(int limit) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_revs_limit')));
    await _send(uriBuilder: uriBuilder, method: 'PUT', body: jsonEncode(limit));
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
    var result;
    if (getViewRequest.keys == null) {
      result = utf8.decode(
          (await _send(uriBuilder: uriBuilder, method: 'GET')).bodyBytes);
    } else {
      Map<String, dynamic> map = Map();
      map['keys'] = getViewRequest.keys;
      result = utf8.decode((await _send(
        uriBuilder: uriBuilder,
        body: jsonEncode(map),
        method: 'POST',
      ))
          .bodyBytes);
    }
    return GetViewResponse.fromJson(
        jsonDecode(result), (json) => fromJsonT(json as Map<String, dynamic>));
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

class MockableIOWebSocketChannel {
  final bool mock;

  late StreamController _mockWs;
  late IOWebSocketChannel _ws;

  MockableIOWebSocketChannel({
    required Uri url,
    this.mock = false,
  }) {
    if (mock) {
      _mockWs = StreamController();
    } else {
      _ws = IOWebSocketChannel.connect(url);
    }
  }

  add(dynamic data) {
    final input = jsonEncode(data);
    if (mock) {
      return _mockWs.sink.add(input);
    } else {
      return _ws.sink.add(input);
    }
  }

  listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final onDataFormat = (data) {
      return onData?.call(jsonDecode(data));
    };
    if (mock) {
      _mockWs.stream.listen(
        onDataFormat,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    } else {
      _ws.stream.listen(
        onDataFormat,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }
  }
}
