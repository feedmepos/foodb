import 'dart:async';
import 'dart:convert';
import 'dart:math';

import "package:crypto/crypto.dart";
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

import 'package:foodb/foodb.dart';

final replicatorVersion = 1;

class ReplicationCheckpoint {
  Doc<ReplicationLog> log;
  List<ChangeResult> processed;
  ReplicationCheckpoint({
    required this.log,
    required this.processed,
  });
}

class ReplicationException implements Exception {
  final Object? err;
  ReplicationException(this.err);

  @override
  String toString() => 'ReplicationException(msg: $err)';
}

class ReplicationStream {
  final void Function() onCancel;
  ReplicationStream({required this.onCancel});

  abort() {
    this.onCancel();
  }
}

String _generateReplicationId(
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
  void Function(ReplicationCheckpoint)? onFinishCheckpoint;
  _Replicator(
    this._source,
    this._target, {
    required this.maxBatchSize,
    this.onFinishCheckpoint,
  });

  cancel() {
    cancelled = true;
  }

  Future<void> run() async {
    final canRun = await _lock.synchronized(() {
      if (isRunning) return false;
      isRunning = true;
      return true;
    });
    if (!canRun || cancelled || pendingList.isEmpty) return;
    try {
      DateTime startTime = DateTime.now();
      String sessionId = Uuid().v4();

      // get last change which has seq (determine by couchdb seq_interval) inside maximum batch to process
      var toProcess =
          pendingList.sublist(0, min(maxBatchSize, pendingList.length));
      toProcess = toProcess.sublist(
          0, toProcess.lastIndexWhere((element) => element.seq != null) + 1);

      // get revs diff
      late Map<String, RevsDiff> revsDiff;
      // await timed('get revs diff', () async {
      Map<String, List<Rev>> groupedChange = new Map();
      toProcess.forEach((changeResult) {
        groupedChange[changeResult.id] =
            changeResult.changes.map((e) => e.rev).toList();
      });
      revsDiff = await _target.revsDiff(body: groupedChange);
      // });

      // have revs diff, need fetch doc
      if (revsDiff.isNotEmpty) {
        List<Doc<Map<String, dynamic>>> toInsert = [];

        // optimization from pouchdb, use allDoc to get doc that missing only 1 generation
        // await timed('handle gen-1 through bulkGet', () async {
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
        // });

        // handle the rest through bulkGet
        // await timed('handle through bulkGet', () async {
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
        // });

        // perform bulkDoc
        // await timed('perform bulkDoc', () async {
        await _target.bulkDocs(body: toInsert, newEdits: false);
        // });

        // ensure full commit
        // await timed('ensure full commit', () async {
        await _target.ensureFullCommit();
        // });
      }
      String lastSeq = toProcess.last.seq!;

      // add checkpoint
      // await timed('add checkpoint', () async {
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
      // });
      pendingList = pendingList.sublist(toProcess.length);
      onFinishCheckpoint
          ?.call(ReplicationCheckpoint(log: targetLog, processed: toProcess));
    } finally {
      isRunning = false;
    }
  }
}

ReplicationStream replicate(
  Foodb source,
  Foodb target, {
  /**
   * override the auto generated replicateId
   */
  String? replicationId,
  /**
   * create target database if not exist
   */
  bool createTarget = false,
  /**
   * run in continuous mode, the replication will be a long running process
   * however user are required to handle network error through onError callback
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
  /**
   * when counter error, can use the stream to decide retry or abort
   */
  void Function(Object?, StackTrace? stackTrace) onError = defaultOnError,
  /**
   * call when got a new change stream result
   */
  void Function(ChangeResult)? onResult,
  /**
   * call when a non-continuous replication completed
   */
  void Function()? onComplete,
  /**
   * call when completed a single checkpoint
   */
  void Function(ReplicationCheckpoint)? onCheckpoint,
}) {
  late ReplicationStream resultStream;
  var _onError = (e, s) {
    resultStream.abort();
    onError(e, s);
  };

  runZonedGuarded(() async {
    late final _Replicator replicator;
    ChangesStream? changeStream;
    var timer = Timer(debounce, () {});
    replicator = _Replicator(source, target, maxBatchSize: maxBatchSize,
        onFinishCheckpoint: (checkpoint) async {
      onCheckpoint?.call(checkpoint);

      if (replicator.pendingList.isNotEmpty) {
        replicator.run();
      } else {
        if (!continuous) {
          onComplete?.call();
        }
      }
    });
    resultStream = new ReplicationStream(onCancel: () {
      replicator.cancel();
      changeStream?.cancel();
    });
    // prepare target
    var sourceInstanceInfo = await source.serverInfo();
    GetServerInfoResponse targetInstanceInfo = await target.serverInfo();
    try {
      await target.info();
    } catch (err) {
      if (createTarget) {
        await target.initDb();
      } else {
        throw ReplicationException(err);
      }
    }

    replicationId ??= await _generateReplicationId(
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
    if (initialSourceLog.model.sessionId == initialTargetLog.model.sessionId &&
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

    changeStream = await source.changesStream(
        ChangeRequest(
            feed: continuous ? ChangeFeed.continuous : ChangeFeed.normal,
            style: 'all_docs',
            heartbeat: heartbeat,
            timeout: timeout,
            seqInterval: continuous ? null : maxBatchSize - 1,
            since: startSeq), onResult: (result) async {
      onResult?.call(result);
      if (continuous) {
        replicator.pendingList.add(result);
        timer.cancel();
        timer = Timer(debounce, replicator.run);
        if (replicator.pendingList.length == maxBatchSize) {
          timer.cancel();
          replicator.run();
        }
      }
    }, onComplete: (result) async {
      if (!continuous) {
        if (result.results.isEmpty) {
          onComplete?.call();
        } else {
          result.results.last.seq =
              result.lastSeq ?? (await source.info()).updateSeq;
          ;
          replicator.pendingList.addAll(result.results);
          replicator.run();
        }
      }
    }, onError: _onError);
  }, _onError);
  return resultStream;
}
