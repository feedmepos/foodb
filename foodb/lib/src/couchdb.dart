part of 'package:foodb/foodb.dart';

class _CouchdbFoodb extends Foodb {
  late http.Client client;
  Uri baseUri;
  http.BaseClient Function()? clientFactory;

  _CouchdbFoodb(
      {required String dbName, required this.baseUri, this.clientFactory})
      : super(dbName: dbName) {
    try {
      this.client = getClient();
      if (!this.baseUri.scheme.toLowerCase().startsWith('http')) {
        throw new Exception('URI scheme must be http/https');
      }
    } catch (err) {
      throw new AdapterException(
          error: 'Invalid uri format', reason: err.toString());
    }
  }

  http.Client getClient() {
    return clientFactory?.call() ?? new http.Client();
  }

  Uri getUri(String path) {
    return Uri.parse("${baseUri.toString()}/$dbName/$path");
  }

  String get dbUri {
    return this.getUri("").toString();
  }

  @override
  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_bulk_get')));
    uriBuilder.queryParameters = convertToParams({"revs": revs});
    var response = (await this.client.post(uriBuilder.build(),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode(body.toJson())));
    if (response.statusCode == 200) {
      return BulkGetResponse<T>.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
          (json) => fromJsonT(json as Map<String, dynamic>));
    }
    throw AdapterException(error: "Invalid Status Code");
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = true}) async {
    var response = (await this.client.post(this.getUri('_bulk_docs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'new_edits': newEdits,
          'docs': body.map((e) {
            Map<String, dynamic> map = e.toJson((value) => value);
            return map;
          }).toList()
        })));

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
  Future<ChangeResponse> changes(ChangeRequest request) async {
    var changeClient = getClient();
    request.feed = ChangeFeed.normal;
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_changes')));
    uriBuilder.queryParameters = convertToParams(request.toJson());
    var res = await changeClient.get(uriBuilder.build());
    return ChangeResponse.fromJson(jsonDecode(res.body));
  }

  @override
  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse)? onComplete,
    Function(ChangeResult)? onResult,
    Function(Object?, StackTrace? stackTrace) onError = defaultOnError,
    Function()? onHeartbeat,
  }) {
    var changeClient = getClient();
    StreamSubscription? subscription;
    Timer? _timer;
    var streamedResponse = ChangesStream(onCancel: () async {
      _timer?.cancel();
      // to close subscription stream,
      // must cancel subscription first before close http client
      //
      // closing client before cancelling subscripntion
      // will have unclosed subscription
      await subscription?.cancel();
      changeClient.close();
    });
    runZonedGuarded(() async {
      UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_changes')));
      uriBuilder.queryParameters = convertToParams(request.toJson());
      if (request.feed == ChangeFeed.normal) {
        var res = await changeClient.get(uriBuilder.build());
        var changeRes = ChangeResponse.fromJson(jsonDecode(res.body));
        changeRes.results.forEach((element) => onResult?.call(element));
        onComplete?.call(changeRes);
      } else {
        var res =
            await changeClient.send(http.Request('get', uriBuilder.build()));
        String cache = "";
        List<ChangeResult> _results = [];

        final st = Stopwatch();

        if (request.feed == ChangeFeed.continuous && request.heartbeat > 0) {
          _timer?.cancel();
          _timer = Timer.periodic(Duration(milliseconds: request.heartbeat),
              (timer) {
            if (st.elapsedMilliseconds > request.heartbeat + 5000) {
              timer.cancel();
              st.stop();
              _timer = null;
              throw new Exception('Heartbeat timed out');
            }
          });
          st.start();
        }

        subscription = res.stream.transform(utf8.decoder).listen((event) {
          if (request.feed == ChangeFeed.continuous) {
            final trimmed = event.trim();
            if (trimmed == '') {
              st.reset();
              onHeartbeat?.call();
            }
            if (trimmed != '') cache += trimmed;
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
    }, (e, s) async {
      await streamedResponse.cancel();
      onError(e, s);
    });

    return streamedResponse;
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() async {
    return EnsureFullCommitResponse.fromJson(
      jsonDecode(
        utf8.decode(
          (await this.client.post(this.getUri('_ensure_full_commit'),
                  headers: {'Content-Type': 'application/json'}))
              .bodyBytes,
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

    var response =
        utf8.decode((await this.client.get(uriBuilder.build())).bodyBytes);
    Map<String, dynamic> result = jsonDecode(response);
    if (result.containsKey('_id')) {
      return Doc<T>.fromJson(
          result, (json) => fromJsonT(json as Map<String, dynamic>));
    } else {
      throw AdapterException(error: response);
    }
  }

  @override
  Future<GetInfoResponse> info() async {
    var response = await this.client.get(this.getUri(''));
    if (response.statusCode != 200) {
      throw AdapterException(error: 'database not found');
    }
    return GetInfoResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)));
  }

  @override
  Future<GetServerInfoResponse> serverInfo() async {
    return GetServerInfoResponse.fromJson(jsonDecode(
        utf8.decode((await this.client.get(this.baseUri)).bodyBytes)));
  }

  @override
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
    var responseBody = jsonDecode(utf8.decode(
        (await this.client.put(uriBuilder.build(), body: jsonEncode(newBody)))
            .bodyBytes));

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
    var result = jsonDecode(
        utf8.decode((await this.client.delete(uriBuilder.build())).bodyBytes));
    if (result['error'] != null) {
      throw AdapterException(error: result['error'], reason: result['reason']);
    }
    return DeleteResponse.fromJson(result);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) async {
    http.Response response = await this.client.post(this.getUri("_revs_diff"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body.map((key, value) =>
            MapEntry(key, value.map((e) => e.toString()).toList()))));
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

    var response = (jsonDecode(utf8.decode((await this.client.post(
            this.getUri('_index'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)))
        .bodyBytes)));

    return IndexResponse.fromJson(response);
  }

  Future<DeleteIndexResponse> deleteIndex({
    required String ddoc,
    required String name,
  }) async {
    return DeleteIndexResponse.fromJson(json.decode((await this.client.delete(
      this.getUri('_index/$ddoc/json/$name'),
      headers: {'Content-Type': 'application/json'},
    ))
        .body));
  }

  @override
  Future<FindResponse<T>> find<T>(FindRequest findRequest,
      T Function(Map<String, dynamic>) fromJsonT) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);

    var response = utf8.decode((await this.client.post(this.getUri('_find'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)))
        .bodyBytes);

    return FindResponse.fromJson(
        jsonDecode(response), (e) => fromJsonT(e as Map<String, dynamic>));
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    var response = jsonDecode(utf8.decode((await this.client.post(
            this.getUri('_explain'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)))
        .bodyBytes));
    return ExplainResponse.fromJson(response);
  }

  @override
  Future<bool> initDb() async {
    final response = await this.client.head(this.getUri(""));
    if (response.statusCode == 404) {
      final response = await this.client.put(this.getUri(""));
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
  Future<bool> destroy() async {
    await this.client.delete(this.getUri(''));
    return true;
  }

  @override
  Future<bool> compact() async {
    await this.client.post(this.getUri('_compact'),
        headers: {'content-type': 'application/json'});
    return true;
  }

  @override
  Future<bool> revsLimit(int limit) async {
    await this.client.put(this.getUri('_revs_limit'), body: jsonEncode(limit));
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
      result = utf8.decode((await this.client.get(
                uriBuilder.build(),
              ))
          .bodyBytes);
    } else {
      Map<String, dynamic> map = Map();
      map['keys'] = getViewRequest.keys;
      result = utf8.decode((await this.client.post(
        uriBuilder.build(),
        body: jsonEncode(map),
        headers: {'Content-Type': 'application/json'},
      ))
          .bodyBytes);
    }
    return GetViewResponse.fromJson(
        jsonDecode(result), (json) => fromJsonT(json as Map<String, dynamic>));
  }

  @override
  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_all_docs')));
    return _view(uriBuilder, getViewRequest, fromJsonT);
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

  @override
  Future<PurgeResponse> purge(Map<String, List<String>> payload) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_purge')));
    final result = utf8.decode((await this.client.post(
      uriBuilder.build(),
      body: jsonEncode(payload),
      headers: {'Content-Type': 'application/json'},
    ))
        .bodyBytes);
    return PurgeResponse.fromJson(jsonDecode(result));
  }
}

Map<String, String> convertToParams(Map<String, dynamic> objects) {
  Map<String, String> params = new Map();
  objects.forEach((key, value) {
    if (value != null) {
      if (value is String) {
        params.putIfAbsent(key, () => value);
      } else if (value is List || value is Map) {
        params.putIfAbsent(key, () => jsonEncode(value));
      } else
        params.putIfAbsent(key, () => value.toString());
    }
  });
  return params;
}
