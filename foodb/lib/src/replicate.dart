import 'dart:async';
import 'dart:math';

import 'package:foodb/foodb.dart';
import 'package:uuid/uuid.dart';

class _Replicator {
  List<ChangeResult> pendingList = [];
  bool isRunning = false;
  bool cancelled = false;
  final int maxBatchSize;
  Foodb _source;
  Foodb _target;
  late Doc<ReplicationLog> sourceLog;
  late Doc<ReplicationLog> targetLog;
  void Function(ReplicationCheckpoint)? onFinishCheckpoint;
  WhereFunction<ChangeResult>? whereChange;
  int _cycleCount = 0;
  bool _cyclePass = false;
  Function(Object?, StackTrace? stackTrace) onError;
  _Replicator(
      this._source,
      this._target, {
        required this.maxBatchSize,
        this.whereChange,
        required this.onError,
      });

  cancel() {
    cancelled = true;
  }

  Future<void> run() async {
    if (isRunning || cancelled) return;
    isRunning = true;
    String sessionId = Uuid().v4();
    DateTime startTime = DateTime.now();
    FoodbDebug.timedStart('replication checkpoint');
    List<ChangeResult> toProcess = [];
    try {
      // get last change which has seq (determine by couchdb seq_interval) inside maximum batch to process
      toProcess = pendingList.sublist(0, min(maxBatchSize, pendingList.length));
      toProcess = toProcess.sublist(
          0, toProcess.lastIndexWhere((element) => element.seq != null) + 1);

      // filter id to process
      var toReplicate = toProcess
          .where((element) => whereChange?.call(element) ?? true)
          .toList();

      if (toProcess.isNotEmpty) {
        // get revs diff
        FoodbDebug.timedStart('<replication>: get revs diff');
        Map<String, List<Rev>> groupedChange = new Map();
        toReplicate.forEach((changeResult) {
          if (changeResult.id != '') {
            // fixed doc with empty id being saved in database
            groupedChange[changeResult.id] =
                changeResult.changes.map((e) => e.rev).toList();
          }
        });
        Map<String, RevsDiff> revsDiff =
        await _target.revsDiff(body: groupedChange);
        FoodbDebug.timedEnd('<replication>: get revs diff');

        // have revs diff, need fetch doc
        if (revsDiff.isNotEmpty) {
          List<Doc<Map<String, dynamic>>> toInsert = [];

          // optimization from pouchdb, use allDoc to get doc that missing only 1 generation
          FoodbDebug.timedStart('<replication>: retrieve gen-1 using allDoc');
          final gen1Ids = revsDiff.keys
              .where((key) =>
          revsDiff[key]!.missing.length == 1 &&
              revsDiff[key]!.missing[0].index == 1)
              .toList();
          if (gen1Ids.length > 0) {
            final docs = await _source.allDocs(
                GetViewRequest(
                    keys: gen1Ids, includeDocs: true, conflicts: true),
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
          FoodbDebug.timedEnd('<replication>: retrieve gen-1 using allDoc');

          // handle the rest through bulkGet
          FoodbDebug.timedStart(
              '<replication>: retrieve the rest using bulkGet');
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
              .expand((BulkGetIdDocs<Map<String, dynamic>> result) => result
              .docs
              .where((BulkGetDoc<Map<String, dynamic>> item) =>
          item.doc != null)
              .expand(
                  (BulkGetDoc<Map<String, dynamic>> item) => [item.doc!])
              .toList()));
          FoodbDebug.timedEnd('<replication>: retrieve the rest using bulkGet');

          // perform bulkDoc
          FoodbDebug.timedStart('<replication>: update DB using bulkDoc');
          await _target.bulkDocs(body: toInsert, newEdits: false);
          FoodbDebug.timedEnd('<replication>: update DB using bulkDoc');

          // ensure full commit
          await _target.ensureFullCommit();
        }
        String lastSeq = toProcess.last.seq!;

        // add checkpoint
        sourceLog = await setReplicationCheckpoint(
            db: _source,
            oldLog: sourceLog,
            startime: startTime,
            lastSeq: lastSeq,
            sessionId: sessionId);
        targetLog = await setReplicationCheckpoint(
            db: _target,
            oldLog: targetLog,
            startime: startTime,
            lastSeq: lastSeq,
            sessionId: sessionId);
        pendingList = pendingList.sublist(toProcess.length);
      }
      isRunning = false;
      onFinishCheckpoint?.call(ReplicationCheckpoint(
          log: targetLog, processed: toProcess, replicated: toReplicate));
      _cyclePass = true;
    } catch (err, st) {
      isRunning = false;
      _cyclePass = false;
      onError(err, st);
    } finally {
      ++_cycleCount;
      FoodbDebug.timedEnd(
          'replication checkpoint',
              (ms) =>
          '<replication> ${_cyclePass ? 'pass' : 'fail'}: checkpoint $_cycleCount, processed ${toProcess.length}, ${ms / toProcess.length} ms/doc');
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
      Duration debounce = const Duration(milliseconds: 30),
      /**
       * when continuous = true, when is size meet but replictor still in debounce, replication cycle will be triggered
       * when continuous = false, batchSize is used in seq_interval in ChangeRequest, let the couchdb decide the upperbound
       */
      int maxBatchSize = 50,
      /**
       * heartbeat for ChangeRequest
       */
      int heartbeat = 10000,
      /**
       * timeout for ChangeRequest
       */
      int timeout = 30000,
      /**
       * Client side run filter for each change result
       * this will prevent the whole document being fetched over the wire during bulkGet
       *
       * Version is required to determine the replication id, so that the replication stay consistance
       * Do update the version when changing the whereFn
       */
      WhereFunction<ChangeResult>? whereChange,
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
      /**
       * call when source and target has unmatched replication log, should return the desire seq, use "0" if want to sync from beginning
       */
      String Function(Doc<ReplicationLog> source, Doc<ReplicationLog> target)?
      noCommonAncestry,
    }) {
  late ReplicationStream resultStream;

  _onError(e, s) {
    resultStream.abort();
    onError(e, s);
  }
  FoodbDebug.timedStart('replication full');
  FoodbDebug.timedStart('replication checkpoint');

  _onComplete() {
    FoodbDebug.timedEnd(
        'replication full', (_) => '<replication>: replication complete');
    onComplete?.call();
  }

  _verifyChangeResult(ChangeResult result, String startSeq) {
    // https://github.com/feedmepos/foodb/issues/11
    // handle broken change feed from couchdb
    if (result.seq != null) {
      // Sequence ID will be an increasing integer, but in couchdb, it encode together with node meta
      // example: 0-g1AAAABbeJzLYWBgYMxgTmGwT84vTc5ISXKA0row2lAPTUQvJbVMr7gsWS85p7S4JLVILyc_OTEnB2gQUyJDHgvDfyDISmTIAgBNxh-c
      // more reading: https://docs.couchdb.org/en/stable/replication/protocol.html#definitions
      final changeSeqInt = int.tryParse(result.seq!.split('-')[0]);
      final startSeqInt = int.tryParse(startSeq.split('-')[0]);
      if (changeSeqInt != null &&
          startSeqInt != null &&
          // base on couchdb, the sequence ID is always increasing,
          changeSeqInt < startSeqInt) {
        throw ReplicationException(
            'broken change result, doc seq smaller than since seq: ${result.seq} ${startSeq}');
      }
    }
  }

  runZonedGuarded(() async {
    late final _Replicator replicator;
    ChangesStream? changeStream;
    var timer = Timer(debounce, () {});
    replicator = _Replicator(source, target,
        maxBatchSize: maxBatchSize,
        whereChange: whereChange,
        onError: _onError);
    resultStream = new ReplicationStream(onCancel: () {
      timer.cancel();
      replicator.cancel();
      changeStream?.cancel();
    });
    // prepare target
    var sourceInstanceInfo = await source.serverInfo();
    GetServerInfoResponse targetInstanceInfo = await target.serverInfo();
    try {
      await target.info();
    } catch (err, stacktrace) {
      if (createTarget) {
        await target.initDb();
      } else {
        print(stacktrace);
        throw ReplicationException(err);
      }
    }
    replicationId ??= await generateReplicationId(
        sourceUuid: sourceInstanceInfo.uuid,
        sourceUri: source.dbUri,
        targetUuid: targetInstanceInfo.uuid,
        targetUri: target.dbUri,
        createTarget: createTarget,
        continuous: continuous,
        filter: whereChange != null ? 'whereChange_${whereChange.id}' : null);

    // get first start seq
    var startSeq = '0';
    final initialSourceLog =
    await retriveReplicationLog(source, replicationId);
    replicator.sourceLog = initialSourceLog;
    final initialTargetLog =
    await retriveReplicationLog(target, replicationId);
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
    if (noCommonAncestry != null &&
        startSeq == "0" &&
        (initialSourceLog.model.sourceLastSeq != "0" ||
            initialTargetLog.model.sourceLastSeq != "0")) {
      startSeq = noCommonAncestry(initialSourceLog, initialTargetLog);
    }

    if (continuous) {
      replicator.onFinishCheckpoint = (checkpoint) async {
        onCheckpoint?.call(checkpoint);
        if (replicator.pendingList.isNotEmpty) {
          replicator.run();
        }
      };
      changeStream = await source.changesStream(
          ChangeRequest(
              feed: ChangeFeed.continuous,
              style: 'all_docs',
              heartbeat: heartbeat,
              timeout: timeout,
              since: startSeq), onResult: (result) async {
        onResult?.call(result);
        _verifyChangeResult(result, startSeq);
        replicator.pendingList.add(result);
        timer.cancel();
        timer = Timer(debounce, replicator.run);
        if (replicator.pendingList.length == maxBatchSize) {
          timer.cancel();
          replicator.run();
        }
      }, onError: _onError);
    } else {
      var pending = 1;
      var startSeqWithLimit = startSeq;

      fetchNormalChangeAndRun() async {
        changeStream = await source.changesStream(
            ChangeRequest(
                feed: ChangeFeed.normal,
                style: 'all_docs',
                heartbeat: heartbeat,
                timeout: timeout,
                seqInterval: maxBatchSize - 1,
                limit: maxBatchSize,
                since: startSeqWithLimit),
            onResult: (result) => onResult?.call(result),
            onComplete: (result) async {
              pending = result.pending ?? 0;
              if (result.results.isNotEmpty) {
                result.results.last.seq = result.lastSeq!;
              }
              startSeqWithLimit = result.lastSeq!;
              result.results.forEach((cr) {
                _verifyChangeResult(cr, startSeq);
                replicator.pendingList.add(cr);
              });
              replicator.run();
            },
            onError: _onError);
      }

      replicator.onFinishCheckpoint = (checkpoint) async {
        onCheckpoint?.call(checkpoint);
        if (pending > 0) {
          fetchNormalChangeAndRun();
        } else {
          _onComplete();
        }
      };
      fetchNormalChangeAndRun();
    }
  }, _onError);
  return resultStream;
}
