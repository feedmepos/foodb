part of 'package:foodb/foodb.dart';

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

  Uuid _uuid = Uuid();

  String _getUniqueId() {
    return _uuid.v1();
  }

  @override
  Future<Doc<T>?> get<T>({
    required String id,
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
    required T Function(Map<String, dynamic> json) fromJsonT,
  }) async {
    final messageId = _getUniqueId();
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
    final uri = uriBuilder.build();
    final message = {
      'method': 'GET',
      'url': uri.toString(),
      'messageId': messageId,
    };
    client.add(message);
    final result = await _await(messageId);
    return result.containsKey('_id')
        ? Doc<T>.fromJson(
            result, (json) => fromJsonT(json as Map<String, dynamic>))
        : null;
  }

  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    final messageId = '';
    // client.send({
    //   'messageId': messageId,
    //   'path': 'put',
    // });
    return await _await(messageId);
  }

  _await(String messageId) async {
    final completer = Completer();
    completers[messageId] = completer;
    final result = await completer.future;
    Future.delayed(Duration(seconds: 3), () {
      completers.remove(messageId);
      throw Exception('timeout');
    });
    return result;
  }

  @override
  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) {
    // TODO: implement allDocs
    throw UnimplementedError();
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body, bool newEdits = true}) {
    // TODO: implement bulkDocs
    throw UnimplementedError();
  }

  @override
  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) {
    // TODO: implement bulkGet
    throw UnimplementedError();
  }

  @override
  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse p1)? onComplete,
    Function(ChangeResult p1)? onResult,
    Function(Object? p1, StackTrace? stackTrace) onError = defaultOnError,
  }) {
    // TODO: implement changesStream
    throw UnimplementedError();
  }

  @override
  Future<bool> compact() {
    // TODO: implement compact
    throw UnimplementedError();
  }

  @override
  Future<IndexResponse> createIndex(
      {required QueryViewOptionsDef index,
      String? ddoc,
      String? name,
      String type = 'json',
      bool? partitioned}) {
    // TODO: implement createIndex
    throw UnimplementedError();
  }

  @override
  // TODO: implement dbUri
  String get dbUri => throw UnimplementedError();

  @override
  Future<DeleteResponse> delete({required String id, required Rev rev}) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<DeleteIndexResponse> deleteIndex(
      {required String ddoc, required String name}) {
    // TODO: implement deleteIndex
    throw UnimplementedError();
  }

  @override
  Future<bool> destroy() {
    // TODO: implement destroy
    throw UnimplementedError();
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() {
    // TODO: implement ensureFullCommit
    throw UnimplementedError();
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) {
    // TODO: implement explain
    throw UnimplementedError();
  }

  @override
  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic> p1) fromJsonT) {
    // TODO: implement find
    throw UnimplementedError();
  }

  @override
  Future<GetInfoResponse> info() {
    // TODO: implement info
    throw UnimplementedError();
  }

  @override
  Future<bool> initDb() {
    // TODO: implement initDb
    throw UnimplementedError();
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) {
    // TODO: implement revsDiff
    throw UnimplementedError();
  }

  @override
  Future<bool> revsLimit(int limit) {
    // TODO: implement revsLimit
    throw UnimplementedError();
  }

  @override
  Future<GetServerInfoResponse> serverInfo() {
    // TODO: implement serverInfo
    throw UnimplementedError();
  }

  @override
  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewId,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) {
    // TODO: implement view
    throw UnimplementedError();
  }
}
