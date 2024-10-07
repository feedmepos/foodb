library foodb;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart' as crypto;
import 'package:foodb/src/common.dart';
import 'package:foodb/src/methods/purge.dart';
import 'package:foodb/src/selector.dart';
import 'package:foodb/src/design_doc.dart';
import 'package:foodb/src/exception.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb/src/methods/bulk_docs.dart';
import 'package:foodb/src/methods/bulk_get.dart';
import 'package:foodb/src/methods/changes.dart';
import 'package:foodb/src/methods/delete.dart';
import 'package:foodb/src/methods/ensure_full_commit.dart';
import 'package:foodb/src/methods/explain.dart';
import 'package:foodb/src/methods/find.dart';
import 'package:foodb/src/methods/index.dart';
import 'package:foodb/src/methods/info.dart';
import 'package:foodb/src/methods/put.dart';
import 'package:foodb/src/methods/revs_diff.dart';
import 'package:foodb/src/methods/server.dart';
import 'package:foodb/src/methods/view.dart';
import 'package:http/http.dart' as http;
import 'package:uri/uri.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

export 'package:foodb/src/replicate.dart';
export 'package:foodb/src/replication_utils.dart';
export 'package:foodb/src/selector.dart';
export 'package:foodb/src/common.dart';
export 'package:foodb/src/design_doc.dart';
export 'package:foodb/src/exception.dart';
export 'package:foodb/src/methods/bulk_docs.dart';
export 'package:foodb/src/methods/bulk_get.dart';
export 'package:foodb/src/methods/changes.dart';
export 'package:foodb/src/methods/delete.dart';
export 'package:foodb/src/methods/ensure_full_commit.dart';
export 'package:foodb/src/methods/explain.dart';
export 'package:foodb/src/methods/find.dart';
export 'package:foodb/src/methods/index.dart';
export 'package:foodb/src/methods/info.dart';
export 'package:foodb/src/methods/put.dart';
export 'package:foodb/src/methods/revs_diff.dart';
export 'package:foodb/src/methods/server.dart';
export 'package:foodb/src/methods/view.dart';
export 'package:foodb/src/methods/purge.dart';
import 'package:web_socket_channel/io.dart';

export 'foodb.dart';
export 'foodb_worker.dart';

part 'src/couchdb.dart';
part 'src/websocket.dart';
part 'src/key_value/key_value_changes.dart';
part 'src/key_value/key_value_find.dart';
part 'src/key_value/key_value_get.dart';
part 'src/key_value/key_value_put.dart';
part 'src/key_value/key_value_util.dart';
part 'src/key_value/key_value_view.dart';
part 'src/key_value/key_value_purge.dart';

enum LOG_LEVEL { trace, debug, off }

class FoodbDebug {
  static LOG_LEVEL logLevel = LOG_LEVEL.off;
  static Map<String, Stopwatch> _cache = {};

  static var printFn = (String message) {
    print(message);
  };
  static _printStopwatch(Stopwatch stopwatch, String step) {
    trace(
        '[${stopwatch.elapsed.inMilliseconds.toString().padLeft(7, ' ')} ms]: $step');
  }

  static trace(String message) {
    if (logLevel.index <= LOG_LEVEL.trace.index) {
      printFn('{TRACE}: $message');
    }
  }

  static debug(String message) {
    if (logLevel.index <= LOG_LEVEL.debug.index) {
      printFn('{DEBUG}: $message');
    }
  }

  static log(String message) {
    debug(message);
  }

  static timed(String step, Function fn) async {
    if (logLevel == LOG_LEVEL.trace) {
      Stopwatch stopwatch = Stopwatch();
      stopwatch.reset();
      stopwatch.start();
      await fn();
      stopwatch.stop();
      _printStopwatch(stopwatch, step);
    } else {
      await fn();
    }
  }

  static timedStart(String step) {
    if (logLevel == LOG_LEVEL.trace) {
      var stopwatch = _cache[step];
      if (stopwatch == null) {
        stopwatch = Stopwatch();
        _cache[step] = stopwatch;
        stopwatch.start();
      }
    }
  }

  static timedEnd(String step, [String Function(int)? message]) {
    if (logLevel == LOG_LEVEL.trace) {
      var stopwatch = _cache[step];
      if (stopwatch != null) {
        _printStopwatch(
            stopwatch, message?.call(stopwatch.elapsedMilliseconds) ?? step);
        stopwatch.stop();
        _cache.remove(step);
      }
    }
  }
}

abstract class Foodb {
  String dbName;
  Foodb({required this.dbName});

  factory Foodb.couchdb({
    required String dbName,
    required Uri baseUri,
    http.BaseClient Function()? clientFactory,
  }) {
    return _CouchdbFoodb(
      dbName: dbName,
      baseUri: baseUri,
      clientFactory: clientFactory,
    );
  }

  factory Foodb.websocket({
    required String dbName,
    required Uri baseUri,
    int timeoutSeconds = 60,
    int reconnectSeconds = 3,
  }) {
    return _WebSocketFoodb(
      dbName: dbName,
      baseUri: baseUri,
      timeoutSeconds: timeoutSeconds,
      reconnectSeconds: reconnectSeconds,
    );
  }

  factory Foodb.keyvalue(
      {required String dbName,
      required KeyValueAdapter keyValueDb,
      bool autoCompaction = false}) {
    return _KeyvalueFoodb(
        dbName: dbName, keyValueDb: keyValueDb, autoCompaction: autoCompaction);
  }

  get isCouchdb {
    return this is _CouchdbFoodb;
  }

  get isKeyValue {
    return this is _KeyvalueFoodb;
  }

  get keyValueAdapter {
    if (this is _KeyvalueFoodb) {
      return (this as _KeyvalueFoodb).keyValueDb;
    }
    return null;
  }

  String get dbUri;

  Future<GetServerInfoResponse> serverInfo();
  Future<GetInfoResponse> info();

  Future<void> clearView(String ddocId, String name);

  Future<Doc<T>> get<T>(
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
      required T Function(Map<String, dynamic> json) fromJsonT});

  Future<Doc<DesignDoc>> fetchDesignDoc({
    required String ddocName,
  }) async {
    return get<DesignDoc>(
        id: '_design/$ddocName', fromJsonT: (json) => DesignDoc.fromJson(json));
  }

  Future<List<Doc<DesignDoc>>> fetchAllDesignDocs() async {
    GetViewResponse<DesignDoc> docs = await allDocs<DesignDoc>(
        GetViewRequest(
            includeDocs: true, startkey: "_design/", endkey: "_design/\ufff0"),
        (json) => DesignDoc.fromJson(json));
    return docs.rows.map<Doc<DesignDoc>>((e) => e.doc!).toList();
  }

  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true});

  Future<DeleteResponse> delete({required String id, required Rev rev});

  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body});

  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT});

  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body, bool newEdits = true});

  Future<EnsureFullCommitResponse> ensureFullCommit();

  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse)? onComplete,
    Function(ChangeResult)? onResult,
    Function(Object?, StackTrace? stackTrace) onError,
    Function()? onHeartbeat,
  });

  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT);

  Future<DeleteIndexResponse> deleteIndex({
    required String ddoc,
    required String name,
  });

  Future<IndexResponse> createIndex(
      {required QueryViewOptionsDef index,
      String? ddoc,
      String? name,
      String type = 'json',
      bool? partitioned});

  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic>) fromJsonT);

  Future<ExplainResponse> explain(FindRequest findRequest);

  Future<bool> initDb();

  Future<bool> destroy();

  Future<bool> compact();

  Future<bool> revsLimit(int limit);

  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewId,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT);

  Future<PurgeResponse> purge(Map<String, List<String>> payload);
}

abstract class JSRuntime {
  evaluate(String script);
}

final allDocDesignDoc = new Doc(
    id: "_design/all_docs",
    model: DesignDoc(
        language: 'query', views: {"all_docs": AllDocDesignDocView()}));

abstract class _AbstractKeyValue extends Foodb {
  KeyValueAdapter keyValueDb;
  JSRuntime? jsRuntime;
  int _revLimit = 1000;
  bool _autoCompaction;

  final _lock = new Lock();

  StreamController<MapEntry<SequenceKey, UpdateSequence>>
      localChangeStreamController = StreamController.broadcast();

  @override
  String get dbUri => '${this.keyValueDb.type}://${this.dbName}';

  _AbstractKeyValue(
      {required dbName,
      required this.keyValueDb,
      required bool autoCompaction,
      this.jsRuntime})
      : _autoCompaction = autoCompaction,
        super(dbName: dbName);

  String encodeSeq(int seq) {
    return '$seq-0';
  }

  int decodeSeq(String seq) {
    return int.parse(seq.split('-')[0]);
  }
}

class _KeyvalueFoodb extends _AbstractKeyValue
    with
        _KeyValueGet,
        _KeyValueFind,
        _KeyValueUtil,
        _KeyValuePut,
        _KeyValueChange,
        _KeyValueView,
        _KeyValuePurge {
  _KeyvalueFoodb(
      {required dbName,
      required KeyValueAdapter keyValueDb,
      required bool autoCompaction,
      JSRuntime? jsRuntime})
      : super(
            dbName: dbName,
            keyValueDb: keyValueDb,
            jsRuntime: jsRuntime,
            autoCompaction: autoCompaction);
}

defaultOnError(Object? e, StackTrace? s) {
  print('[EXCEPTION] $e, trace \n$s');
}
