// ignore_for_file: public_member_api_docs, sort_constructors_first
library foodb;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb/src/common.dart';
import 'package:foodb/src/design_doc.dart';
import 'package:foodb/src/exception.dart';
import 'package:foodb/src/methods/bulk_docs.dart';
import 'package:foodb/src/methods/bulk_get.dart';
import 'package:foodb/src/methods/changes.dart';
import 'package:foodb/src/methods/delete.dart';
import 'package:foodb/src/methods/ensure_full_commit.dart';
import 'package:foodb/src/methods/explain.dart';
import 'package:foodb/src/methods/find.dart';
import 'package:foodb/src/methods/index.dart';
import 'package:foodb/src/methods/info.dart';
import 'package:foodb/src/methods/purge.dart';
import 'package:foodb/src/methods/put.dart';
import 'package:foodb/src/methods/revs_diff.dart';
import 'package:foodb/src/methods/server.dart';
import 'package:foodb/src/methods/view.dart';
import 'package:foodb/src/selector.dart';
import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import 'package:uri/uri.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

export 'foodb.dart';
export 'foodb_worker.dart';
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
export 'package:foodb/src/methods/purge.dart';
export 'package:foodb/src/methods/put.dart';
export 'package:foodb/src/methods/revs_diff.dart';
export 'package:foodb/src/methods/server.dart';
export 'package:foodb/src/methods/view.dart';
export 'package:foodb/src/replicate.dart';
export 'package:foodb/src/selector.dart';

part 'src/couchdb.dart';
part 'src/key_value/key_value_changes.dart';
part 'src/key_value/key_value_find.dart';
part 'src/key_value/key_value_get.dart';
part 'src/key_value/key_value_purge.dart';
part 'src/key_value/key_value_put.dart';
part 'src/key_value/key_value_util.dart';
part 'src/key_value/key_value_view.dart';
part 'src/websocket.dart';

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

  Foodb({required this.dbName}) {}

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

  factory Foodb.keyvalue({
    required String dbName,
    required KeyValueAdapter keyValueDb,
    bool autoCompaction = false,
    bool isolateLeader = false,
  }) {
    return KeyvalueFoodb(
        dbName: dbName,
        keyValueDb: keyValueDb,
        autoCompaction: autoCompaction,
        isolateLeader: isolateLeader);
  }

  get isCouchdb {
    return this is _CouchdbFoodb;
  }

  get isKeyValue {
    return this is KeyvalueFoodb;
  }

  get keyValueAdapter {
    if (this is KeyvalueFoodb) {
      return (this as KeyvalueFoodb).keyValueDb;
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

class KeyvalueFoodbIsolateRef {
  SendPort isolateMemberSendPort;
  bool isLeader;
  StreamSubscription? localSubscription;
  KeyvalueFoodbIsolateRef({
    required this.isolateMemberSendPort,
    required this.isLeader,
  });
}

abstract class _AbstractKeyValue extends Foodb {
  KeyValueAdapter keyValueDb;
  JSRuntime? jsRuntime;
  int _revLimit = 1000;
  bool _autoCompaction;
  int get revLimit => _revLimit;
  get autoCompaction => _autoCompaction;

  Lock _lock = Lock();
  bool isolateLeader;
  ReceivePort receiveFromIsolateMember = ReceivePort();
  late KeyvalueFoodbIsolateRef isolateReference;
  List<KeyvalueFoodbIsolateRef> memberships = [];

  StreamController<MapEntry<SequenceKey, UpdateSequence>>
      localChangeStreamController = StreamController.broadcast();
  StreamController<MapEntry<SequenceKey, UpdateSequence>>
      clusterChangeStreamController = StreamController.broadcast();

  // Buffer for ordered sequence delivery
  Map<int, MapEntry<SequenceKey, UpdateSequence>> _sequenceBuffer = {};
  int _expectedNextSeq = 1;
  Timer? _bufferFlushTimer;

  // Buffer configuration
  static const Duration _bufferFlushDelay = Duration(milliseconds: 100);
  static const int _maxBufferSize = 1000;

  @override
  String get dbUri => '${this.keyValueDb.type}://${this.dbName}';

  // Buffer management methods
  void _addToSequenceBuffer(MapEntry<SequenceKey, UpdateSequence> entry) {
    final seq = entry.key.key!;

    // Skip if this sequence is older than what we've already processed
    if (seq < _expectedNextSeq) {
      FoodbDebug.debug(
          'Skipping old sequence: $seq, expected: $_expectedNextSeq');
      return;
    }

    // Prevent buffer from growing too large
    if (_sequenceBuffer.length >= _maxBufferSize) {
      FoodbDebug.debug('Buffer size limit reached, forcing flush');
      _flushRemainingBuffer();
    }

    _sequenceBuffer[seq] = entry;
    _flushSequenceBuffer();
  }

  void _flushSequenceBuffer() {
    // Cancel existing timer
    _bufferFlushTimer?.cancel();

    // Flush all consecutive sequences starting from expected
    while (_sequenceBuffer.containsKey(_expectedNextSeq)) {
      final entry = _sequenceBuffer.remove(_expectedNextSeq)!;
      clusterChangeStreamController.sink.add(entry);
      _expectedNextSeq++;
    }

    // Set a timer to flush remaining buffer after a delay (handles gaps)
    if (_sequenceBuffer.isNotEmpty) {
      _bufferFlushTimer = Timer(_bufferFlushDelay, () {
        _flushRemainingBuffer();
      });
    }
  }

  void _flushRemainingBuffer() {
    if (_sequenceBuffer.isNotEmpty) {
      // Find the smallest sequence number and update expected
      final minSeq = _sequenceBuffer.keys.reduce((a, b) => a < b ? a : b);
      FoodbDebug.debug(
          'Jumping sequence from $_expectedNextSeq to $minSeq due to gap timeout');
      _expectedNextSeq = minSeq;
      _flushSequenceBuffer();
    }
  }

  void _resetSequenceBuffer({int? startSeq}) {
    _bufferFlushTimer?.cancel();
    _sequenceBuffer.clear();
    _expectedNextSeq = startSeq ?? 1;
  }

  Future<void> _initializeSequenceBuffer() async {
    try {
      // Get the current last sequence from the database
      var lastSeq = keyValueDb.last<SequenceKey>(SequenceKey(key: 0));
      _expectedNextSeq = (lastSeq?.key.key ?? 0) + 1;
      FoodbDebug.debug(
          'Initialized sequence buffer, expecting sequence: $_expectedNextSeq');
    } catch (e) {
      FoodbDebug.debug('Failed to initialize sequence buffer: $e');
      _expectedNextSeq = 1;
    }
  }

  bool addIsolateMembership(KeyvalueFoodbIsolateRef reference) {
    // if it is a new referece add it into membership
    if (memberships.every(
        (m) => m.isolateMemberSendPort != reference.isolateMemberSendPort)) {
      _lock.synchronized(() {
        memberships.add(reference);
        // if the reference is not self, return own reference to the requester so that the communication is two way
        if (reference.isolateMemberSendPort !=
            receiveFromIsolateMember.sendPort) {
          reference.isolateMemberSendPort.send(isolateReference);
        }
        // if this instance is the leader, link all the member together
        if (isolateLeader) {
          print('leader propagading member');
          memberships.forEach((m) {
            if (m.isolateMemberSendPort != reference.isolateMemberSendPort) {
              print('leader ask other member to add the new member');
              m.isolateMemberSendPort.send(reference);
            }
          });
        }

        // publish all the local change to member
        reference.localSubscription =
            localChangeStreamController.stream.listen((data) {
          reference.isolateMemberSendPort.send(data);
        });
      });
      return true;
    }
    return false;
  }

  void dispose() {
    _bufferFlushTimer?.cancel();
    localChangeStreamController.close();
    clusterChangeStreamController.close();
    receiveFromIsolateMember.close();
  }

  _AbstractKeyValue(
      {required dbName,
      required this.keyValueDb,
      required bool autoCompaction,
      isolateLeader = false,
      this.jsRuntime})
      : _autoCompaction = autoCompaction,
        isolateLeader = isolateLeader,
        super(dbName: dbName) {
    isolateReference = KeyvalueFoodbIsolateRef(
      isolateMemberSendPort: receiveFromIsolateMember.sendPort,
      isLeader: isolateLeader,
    );

    // Initialize sequence buffer with current database state
    _initializeSequenceBuffer();

    // Set up buffered change streams for ordered delivery
    localChangeStreamController.stream.listen((data) {
      _addToSequenceBuffer(data);
    });
    receiveFromIsolateMember.listen((data) {
      if (data is KeyvalueFoodbIsolateRef) {
        addIsolateMembership(data);
      }
      if (data is MapEntry<SequenceKey, UpdateSequence>) {
        _addToSequenceBuffer(data);
      }
    });
  }

  String encodeSeq(int seq) {
    return '$seq-0';
  }

  int decodeSeq(String seq) {
    return int.parse(seq.split('-')[0]);
  }
}

class KeyvalueFoodb extends _AbstractKeyValue
    with
        _KeyValueGet,
        _KeyValueFind,
        _KeyValueUtil,
        _KeyValuePut,
        _KeyValueChange,
        _KeyValueView,
        _KeyValuePurge {
  KeyvalueFoodb(
      {required dbName,
      required KeyValueAdapter keyValueDb,
      required bool autoCompaction,
      bool isolateLeader = false,
      JSRuntime? jsRuntime})
      : super(
          dbName: dbName,
          keyValueDb: keyValueDb,
          jsRuntime: jsRuntime,
          autoCompaction: autoCompaction,
          isolateLeader: isolateLeader,
        );
}

defaultOnError(Object? e, StackTrace? s) {
  print('[EXCEPTION] $e, trace \n$s');
}
