import 'dart:async';
import 'dart:convert';
import 'dart:math';
import "package:crypto/crypto.dart";
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/adapter/methods/server.dart';
import 'package:foodb/common/replication.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

final replicatorVersion = 1;
emptyCallback() {}

class ReplicationException implements Exception {
  final String msg;
  ReplicationException(this.msg);

  @override
  String toString() => 'ReplicationException(msg: $msg)';
}

abstract class ReplicationEvent {}

class ReplicationCheckpointEvent extends ReplicationEvent {
  Doc<ReplicationLog> log;
  List<ChangeResult> processed;
  ReplicationCheckpointEvent(this.log, this.processed);
}

class ReplicationErrorEvent extends ReplicationEvent {
  Object err;
  ReplicationErrorEvent(Object this.err);
}

class ReplicationCompleteEvent extends ReplicationEvent {}

class ReplicationStream {
  Stream<ReplicationEvent> _stream;
  final void Function() onCancel;
  final void Function() onRetry;
  ReplicationStream(this._stream,
      {required this.onCancel, required this.onRetry});

  listen({
    /**
   * when counter error, can use the stream to decide retry or abort
   */
    void Function(ReplicationErrorEvent)? onError,
    /**
   * call when a non-continuous replication completed
   */
    void Function(ReplicationCompleteEvent)? onComplete,
    /**
   * call when completed a single checkpoint
   */
    void Function(ReplicationCheckpointEvent)? onCheckpoint,
  }) {
    _stream.listen((event) {
      if (event is ReplicationCheckpointEvent) {
        onCheckpoint?.call(event);
      } else if (event is ReplicationCompleteEvent) {
        onComplete?.call(event);
      } else if (event is ReplicationErrorEvent) {
        onError?.call(event);
      }
    });
  }

  abort(){
    this.onCancel();
  }

  retry() {
    this.onRetry();
  }
}

_generateReplicationId(
    {String? sourceUuid,
    String? sourceUri,
    String? targetUuid,
    String? targetUri,
    bool? createTarget,
    bool? continuous,
    Map<String, String>? headers,
    String? filterFn,
    Map<String, String>? params}) {
  return md5
      .convert(utf8.encode([
        sourceUuid ?? "",
        sourceUri ?? "",
        targetUuid ?? "",
        targetUri ?? "",
        createTarget?.toString() ?? "",
        continuous?.toString() ?? "",
        headers?.toString() ?? "",
        filterFn ?? "",
        params?.toString() ?? ""
      ].join()))
      .toString();
}

Future<Doc<ReplicationLog>> _retriveReplicationLog(
    Foodb db, replicationId) async {
  final id = "_local/$replicationId";
  final exist = await db.get(
      id: "_local/$replicationId",
      fromJsonT: (json) => ReplicationLog.fromJson(json));
  if (exist != null) {
    return exist;
  }
  return Doc(
      id: id,
      model: ReplicationLog(
          history: [],
          replicationIdVersion: 1,
          sessionId: "",
          sourceLastSeq: "0"));
}

Future<Doc<ReplicationLog>> _setReplicationCheckpoint(
    {required Foodb db,
    required Doc<ReplicationLog> oldLog,
    required DateTime startime,
    required String lastSeq,
    required String sessionId}) async {
  final newReplicationLog = ReplicationLog(
      history: [
        History(
          endTime: DateTime.now().toIso8601String(),
          startTime: DateTime.now().toIso8601String(),
          recordedSeq: lastSeq,
          sessionId: sessionId,
        ),
        ...oldLog.model.history.sublist(0, min(oldLog.model.history.length, 5))
      ],
      replicationIdVersion: replicatorVersion,
      sessionId: sessionId,
      sourceLastSeq: lastSeq);

  final doc = Doc<Map<String, dynamic>>(
      id: oldLog.id, rev: oldLog.rev, model: newReplicationLog.toJson());
  final putResponse = await db.put(doc: doc);
  return Doc(id: oldLog.id, rev: putResponse.rev, model: newReplicationLog);
}

parseSeqInt(String seq) {
  return int.tryParse(seq.split('-')[0]) ?? 0;
}

class _Replicator {
  final _lock = Lock();
  List<ChangeResult> pendingList = [];
  bool isRunning = false;
  bool cancelled = false;
  final int maxBatchSize;
  Foodb _source;
  Foodb _target;
  late Doc<ReplicationLog> sourceLog;
  late Doc<ReplicationLog> targetLog;
  void Function(Object)? onError;
  void Function(Doc<ReplicationLog>, List<ChangeResult>)? onFinishCheckpoint;
  _Replicator(
    this._source,
    this._target, {
    required this.maxBatchSize,
    this.onError,
    this.onFinishCheckpoint,
  });

  cancel() {
    cancelled = true;
  }

  run() async {
    await _lock.synchronized(() {
      if (isRunning || cancelled || pendingList.isEmpty) return;
      isRunning = true;
    });
    try {
      DateTime startTime = DateTime.now();
      String sessionId = Uuid().v4();

      // get last change which has seq (determine by couchdb seq_interval) inside maximum batch to process
      var toProcess =
          pendingList.sublist(0, min(maxBatchSize, pendingList.length));
      toProcess = toProcess.sublist(
          0, toProcess.lastIndexWhere((element) => element.seq != null) + 1);

      // get revs diff
      Map<String, List<Rev>> groupedChange = new Map();
      toProcess.forEach((changeResult) {
        groupedChange[changeResult.id] =
            changeResult.changes.map((e) => e.rev).toList();
      });
      Map<String, RevsDiff> revsDiff =
          await _target.revsDiff(body: groupedChange);

      // have revs diff, need fetch doc
      if (revsDiff.isNotEmpty) {
        List<Doc<Map<String, dynamic>>> toInsert = [];

        // optimization from pouchdb, use allDoc to get doc that missing only 1 generation
        final gen1Ids = revsDiff.keys
            .where((key) =>
                revsDiff[key]!.missing.length == 1 &&
                revsDiff[key]!.missing[0].index == 1)
            .toList();
        if (gen1Ids.length > 0) {
          final docs = await _source.allDocs(
              GetViewRequest(keys: gen1Ids, includeDocs: true, conflicts: true),
              (json) => json);
          if (cancelled) throw ReplicationException('cancelled');
          docs.rows.forEach((row) {
            if (row.doc == null ||
                row.doc!.deleted == true ||
                row.doc!.rev!.index != 1 ||
                (row.doc!.conflicts != null &&
                    row.doc!.conflicts!.length > 0)) {
              return;
            }
            toInsert.add(row.doc!);
            revsDiff.remove(row.id);
          });
        }

        // handle the rest through bulkGet
        toInsert.addAll((await _source.bulkGet<Map<String, dynamic>>(
                body: BulkGetRequest(
                    docs: revsDiff.keys
                        .expand((k) => revsDiff[k]!
                            .missing
                            .map((r) => BulkGetRequestDoc(id: k, rev: r)))
                        .toList()),
                revs: true,
                fromJsonT: (json) => json))
            .results
            .expand((BulkGetIdDocs<Map<String, dynamic>> result) => result.docs
                .where(
                    (BulkGetDoc<Map<String, dynamic>> item) => item.doc != null)
                .expand((BulkGetDoc<Map<String, dynamic>> item) => [item.doc!])
                .toList()));

        // perform bulkDoc
        await _target.bulkDocs(body: toInsert, newEdits: false);

        // ensure full commit
        await _target.ensureFullCommit();
      }
      String lastSeq = toProcess.last.seq!;

      // add checkpoint
      sourceLog = await _setReplicationCheckpoint(
          db: _source,
          oldLog: sourceLog,
          startime: startTime,
          lastSeq: lastSeq,
          sessionId: sessionId);
      targetLog = await _setReplicationCheckpoint(
          db: _target,
          oldLog: targetLog,
          startime: startTime,
          lastSeq: lastSeq,
          sessionId: sessionId);
      pendingList = pendingList.sublist(toProcess.length);
      isRunning = false;
      onFinishCheckpoint?.call(targetLog, toProcess);
    } catch (err) {
      isRunning = false;
      onError?.call(err);
    }
  }
}

Future<ReplicationStream> replicate(
  Foodb source,
  Foodb target, {
  /**
   * create target database if not exist
   */
  bool createTarget = false,
  /**
   * run in continuous mode, the replication will be a long running process
   */
  bool continuous = false,
  /**
   * used when continuous = true.
   * specify a certain millisecond before kick start the cycle
   */
  Duration debounce = const Duration(microseconds: 3000),
  /**
   * when continuous = true, when is size meet but replictor still in debounce, replication cycle will be triggered
   * when continuous = false, batchSize is used in seq_interval in ChangeRequest, let the couchdb decide the upperbound
   */
  int maxBatchSize = 25,
  /**
   * heartbeat for ChangeRequest
   */
  int heartbeat = 10000,
  /**
   * timeout for ChangeRequest
   */
  int timeout = 30000,
}) async {
  StreamController<ReplicationEvent> _stream = new StreamController();
  late ReplicationStream resultStream;
  late final _Replicator replicator;
  ChangesStream? changeStream;
  var timer = Timer(debounce, () {});

  replicator = _Replicator(source, target, maxBatchSize: maxBatchSize,
      onFinishCheckpoint: (log, changes) {
    if (!_stream.isClosed) {
      _stream.sink.add(ReplicationCheckpointEvent(log, changes));
      if (replicator.pendingList.isNotEmpty) {
         replicator.run();
      } 
      else {
        if (!continuous) {
          _stream.sink.add(ReplicationCompleteEvent());
        }
      }
    }
  }, onError: (err) {
    if (!_stream.isClosed) _stream.sink.add(ReplicationErrorEvent(err));
  });
  resultStream = new ReplicationStream(_stream.stream, onCancel: () {
    replicator.cancel();
    changeStream?.cancel();
    _stream.close();
  }, onRetry: () {
    if (changeStream == null) {
      throw ReplicationException(
          'unable to start change stream, please call replicate again');
    }
    replicator.run();
  });
  () async {
    try {
      // prepare target
      var sourceInstanceInfo = await source.serverInfo();
      GetServerInfoResponse targetInstanceInfo = await target.serverInfo();
      try {
        await target.info();
      } catch (err) {
        if (createTarget) {
          await target.initDb();
        } else {
          _stream.sink.add(ReplicationErrorEvent(err));
        }
      }

      final replicationId = await _generateReplicationId(
          sourceUuid: sourceInstanceInfo.uuid,
          sourceUri: source.dbUri,
          targetUuid: targetInstanceInfo.uuid,
          targetUri: target.dbUri,
          createTarget: createTarget,
          continuous: continuous);

      // get first start seq
      var startSeq = '0';
      final initialSourceLog =
          await _retriveReplicationLog(source, replicationId);
      replicator.sourceLog = initialSourceLog;
      final initialTargetLog =
          await _retriveReplicationLog(target, replicationId);
      replicator.targetLog = initialTargetLog;
      if (initialSourceLog.model.sessionId ==
              initialTargetLog.model.sessionId &&
          initialSourceLog.model.sessionId != "") {
        startSeq = initialTargetLog.model.sourceLastSeq;
      }
      for (final historyA in initialTargetLog.model.history) {
        if (initialSourceLog.model.history
            .any((historyB) => historyB.sessionId == historyA.sessionId)) {
          startSeq = historyA.recordedSeq;
          break;
        }
      }

      source
          .changesStream(ChangeRequest(
              feed: continuous ? ChangeFeed.continuous : ChangeFeed.normal,
              style: 'all_docs',
              heartbeat: heartbeat,
              timeout: timeout,
              seqInterval: continuous ? null : maxBatchSize - 1,
              since: startSeq))
          .then((value) {
        changeStream = value;
        changeStream!.listen(onResult: (result) {
          if (continuous) {
            replicator.pendingList.add(result);
            timer.cancel();
            timer = Timer(debounce,  replicator.run);
            if (replicator.pendingList.length == maxBatchSize) {
              timer.cancel();
              replicator.run();
            }
          }
        }, onComplete: (result) async {
          if (!continuous) {
            if (result.results.isEmpty) {
              _stream.sink.add(ReplicationCompleteEvent());
            } else {
              result.results.last.seq =
                  result.lastSeq ?? (await source.info()).updateSeq;
              ;
              replicator.pendingList.addAll(result.results);
              replicator.run();
            }
          }
        });
      });
    } catch (err) {
      _stream.sink.add(ReplicationErrorEvent(err));
    }
  }();
  return resultStream;
}

fastInitialReplicate(Foodb source, Foodb target) {}
