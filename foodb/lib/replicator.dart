import 'dart:async';
import 'dart:math';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/open_revs.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/replication.dart';
import 'package:foodb/common/rev.dart';
import 'package:uuid/uuid.dart';

class Replicator {
  AbstractAdapter source;
  AbstractAdapter target;

  final String replicationID = "2b93a1dd-c17f-4422-addd-d432c5ae39c6";
  final String replicationID2 = "49ef41c4-6d12-4eff-8d22-62e2fdb82f5b";
  final uuidGenerator = new Uuid();

  GetInfoResponse? sourceInfo;
  GetInfoResponse? targetInfo;
  Doc<ReplicationLog>? replicationLog;
  String? replicationId;
  bool? complete;
  Function(dynamic)? onComplete;
  late Function(Exception, Function callback) onError;
  late Function(dynamic) onData;

  List<ChangeResult> dbChanges = [];
  bool running = false;
  bool live = false;
  int limit = 25;
  Duration timeout = Duration(seconds: 3);
  Timer? timer;
  String? sourceSequence;
  Map<String, Function> onCancels = {};
  Replicator({required this.source, required this.target});

  Future<void> initialReplicate() async {
    try {
      this.sourceInfo = await getSourceInformation();
      onData(sourceInfo);

      this.replicationId = await generateReplicationID();
      onData(replicationID);

      this.replicationLog = await retrieveReplicationLog();
      onData(replicationLog ?? "No Existing Replication Log");
    } catch (e) {
      throw (e);
    }
  }

  Future<void> _runReplicationCycle(String since, String? upperbound) async {
    if (running) {
      return;
    } else {
      running = true;
      try {
        int untilIndex = min(limit, dbChanges.length);
        List<ChangeResult> toProcess = dbChanges.sublist(0, untilIndex);

        this.sourceSequence =
            toProcess.isNotEmpty ? toProcess.last.seq : sourceInfo!.updateSeq;
        onData(toProcess);

        Map<String, List<String>> changes = await readBatchOfChanges(toProcess);
        onData(changes);

        Map<String, RevsDiff> revsDiff =
            await calculateRevisionDifference(changes);
        onData(revsDiff);

        if (revsDiff.isNotEmpty) {
          List<Doc<Map<String, dynamic>>> docs =
              await fetchChangedDocuments(revsDiff: revsDiff);
          onData(docs);

          BulkDocResponse? bulkDocResponse = await target.lock.synchronized(
              () async => await uploadBatchOfChangedDocuments(body: docs));
          onData(bulkDocResponse);

          EnsureFullCommitResponse ensureFullCommitResponse =
              await target.ensureFullCommit();
          onData(ensureFullCommitResponse);

          this.targetInfo = await getTargetInformation();
          onData(targetInfo);

          PutResponse insertResponse = await recordReplicationCheckpoint();
          if (insertResponse.ok == true) {
            onData(insertResponse);
          }
        } else {
          this.targetInfo = await getTargetInformation();
          onData(targetInfo);

          PutResponse insertResponse = await target.lock
              .synchronized(() async => await recordReplicationCheckpoint());

          if (insertResponse.ok == true) {
            onData(insertResponse);
          }
        }
        dbChanges.removeRange(0, untilIndex);
        onData("One Cycle Completed");

        if (!this.live && this.complete!) {
          if (dbChanges.length == 0) {
            this.onComplete!("Completed");
          } else {
            this.running = false;
            await _runReplicationCycle(since, upperbound);
          }
        }
      } catch (error) {
        this.running = false;
        await errorCallback(since: since, error: error);
      } finally {
        this.running = false;
      }
    }
  }

  Future<void> _listenToNormalChanges(
      {required String since, required String upperbound}) async {
    try {
      int upperboundInt = int.parse(upperbound.split('-')[0]);
      listenToChangesFeed(feed: ChangeFeed.normal, since: since)
          .then((changeStream) async {
        changeStream.listen(
            onResult: (changeResult) => dbChanges.add(changeResult),
            onComplete: (changeResponse) async {
              try {
                complete = false;

                if (int.parse(changeResponse.lastSeq!.split('-')[0]) >=
                    upperboundInt) {
                  complete = true;
                  dbChanges = dbChanges
                      .where((element) =>
                          int.parse(element.seq.split('-')[0]) <= upperboundInt)
                      .toList();
                }

                await _runReplicationCycle(since, upperbound);

                if (!complete!) {
                  sourceInfo = await getSourceInformation();
                  await this.cancel(since);
                  await _listenToNormalChanges(
                      since: changeResponse.lastSeq!, upperbound: upperbound);
                }
              } catch (error) {
                await errorCallback(since: since, error: error);
              }
            });
        this.onCancels[since] = () async {
          await changeStream.cancel();
        };
      });
    } catch (error) {
      await errorCallback(since: since, error: error);
    }
  }

  Future<void> _listenToContinuousChanges({required String since}) async {
    try {
      listenToChangesFeed(feed: ChangeFeed.continuous, since: since)
          .then((changeStream) async {
        this.onCancels[since] = changeStream.cancel;
        changeStream.listen(onResult: (changeResult) async {
          try {
            dbChanges.add(changeResult);
            if (dbChanges.length == limit) {
              _runReplicationCycle(since, "");
            }
          } catch (error) {
            await errorCallback(since: since, error: error);
          }
        });
        this.onCancels[since] = () async {
          await changeStream.cancel();
        };
      });

      this.timer = Timer.periodic(timeout, (timer) async {
        try {
          if (dbChanges.length > 0) _runReplicationCycle(since, "");
        } catch (error) {
          await errorCallback(since: since, error: error);
        }
      });
    } catch (error) {
      await errorCallback(since: since, error: error);
    }
  }

  replicate(
      {Function(dynamic)? onComplete,
      required Function(dynamic) onData,
      required Function(Exception, Function callback) onError,
      bool live = false,
      int limit = 25,
      Duration timeout = const Duration(seconds: 3)}) async {
    this.live = live;
    this.limit = limit;
    this.timeout = timeout;

    if (!this.live) {
      this.onComplete = onComplete!;
    }
    this.onData = onData;
    this.onError = onError;

    try {
      await initialReplicate();
      String sourceLastSeq = this.replicationLog?.model.sourceLastSeq ?? '0';
      if (live) {
        _listenToContinuousChanges(since: sourceLastSeq);
      } else
        _listenToNormalChanges(
            since: sourceLastSeq, upperbound: sourceInfo?.updateSeq ?? "0");
    } catch (e) {
      await errorCallback(error: e);
    }
  }

  errorCallback({String? since, required Object error}) async {
    this.dbChanges.clear();
    if (since != null) await this.cancel(since);
    this.onError(Exception(error), () {
      replicate(
          live: live,
          limit: limit,
          timeout: timeout,
          onData: onData,
          onError: onError,
          onComplete: onComplete);
    });
  }

  cancel(String since) async {
    this.timer?.cancel();
    if (this.onCancels.containsKey(since)) await this.onCancels[since]!();
    this.onCancels.remove(since);
  }

  cancelAll() {
    this.timer?.cancel();
    this.onCancels.forEach((key, cancelFn) {
      cancelFn();
    });
    this.onCancels.clear();
  }

  Future<GetInfoResponse> getSourceInformation() async {
    return await source.info();
  }

  Future<GetInfoResponse> getTargetInformation() async {
    return await target.info();
  }

  Future<void> getPeersInformation() async {
    this.sourceInfo = await getSourceInformation();
    this.targetInfo = await getTargetInformation();
  }

  Future<String> generateReplicationID() async {
    //***/
    return Future.value(replicationID);
  }

  Future<Doc<ReplicationLog>?> retrieveReplicationLog() async {
    return await target.get(
        //id: "_local/${replicationId!}",
        id: "_local/2b93a1dd-c17f-4422-addd-d432c5ae39c6",
        fromJsonT: (json) => ReplicationLog.fromJson(json));
  }

  Future<ChangesStream> listenToChangesFeed(
      {required String feed, required String since}) async {
    return source.changesStream(ChangeRequest(
        feed: feed,
        style: 'all_docs',
        heartbeat: 10000,
        since: since,
        conflicts: true,
        limit: !live ? limit : null));
  }

  Future<Map<String, List<String>>> readBatchOfChanges(
      List<ChangeResult> changeResults) async {
    Map<String, List<String>> changes = new Map();
    changeResults.forEach((changeResult) {
      changes[changeResult.id] =
          changeResult.changes.map((e) => e.rev.toString()).toList();
    });
    return changes;
  }

  Future<Map<String, RevsDiff>> calculateRevisionDifference(
      Map<String, List<String>> body) async {
    return await target.revsDiff(body: body);
  }

  Future<List<Doc<Map<String, dynamic>>>> fetchChangedDocuments(
      {required Map<String, RevsDiff> revsDiff}) async {
    List<Map<String, dynamic>> body = [];
    revsDiff.forEach((key, value) {
      value.missing.forEach((rev) {
        body.add({"id": key, "rev": rev.toString()});
      });
    });
    return
        (await source.bulkGet<Map<String, dynamic>>(
                body: body,
                revs: true,
                latest: true,
                fromJsonT: (json) => json))
            .results
            .expand((BulkGetIdDocs<Map<String,dynamic>> result) => result
                .docs.where((BulkGetDoc<Map<String,dynamic>> item) => item.doc!=null)
                .expand(
                    (BulkGetDoc<Map<String,dynamic>> item) => [item.doc!])
                .toList())
            .toList();

  }

  Future<BulkDocResponse> uploadBatchOfChangedDocuments(
      {required List<Doc<Map<String, dynamic>>> body}) async {
    BulkDocResponse bulkDocResponse =
        await target.bulkDocs(body: body, newEdits: false);
    return bulkDocResponse;
  }

  Rev _getRev(Rev? rev) {
    if (rev == null)
      return Rev.fromString("0-1");
    else
      return Rev.fromString("0-${(int.parse(rev.md5) + 1)}");
  }

  Future<PutResponse> recordReplicationCheckpoint() async {
    replicationLog = Doc<ReplicationLog>(
        id: replicationLog?.id ?? "_local/$replicationId",
        rev: _getRev(replicationLog?.rev),
        model: ReplicationLog(
            history: [
              History(
                endTime: this.targetInfo!.updateSeq,
                startTime: this.sourceInfo!.instanceStartTime,
                recordedSeq: this.targetInfo!.updateSeq,
              )
            ],
            replicationIdVersion: replicationLog == null
                ? 1
                : replicationLog!.model.replicationIdVersion + 1,
            sessionId: uuidGenerator.v4(),
            sourceLastSeq: this.sourceSequence!));

    Doc<Map<String, dynamic>> newReplicationLog = new Doc<Map<String, dynamic>>(
        id: "_local/${replicationId!}",
        rev: replicationLog!.rev,
        model: replicationLog!.model.toJson());

    // throw AdapterException(error: "Replicator error");
    PutResponse putResponse =
        await target.putLocal(doc: newReplicationLog, newEdits: false);
    return putResponse;
  }
}
