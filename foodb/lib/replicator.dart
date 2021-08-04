import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/replication.dart';
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

  Function(dynamic)? onComplete;
  Function()? onCancel;
  late Function(Exception, Function callback) onError;
  late Function(dynamic) onData;

  List<ChangeResult> dbChanges = [];
  bool running = false;
  bool live = false;
  int limit = 25;
  Duration timeout = Duration(seconds: 3);
  Timer? timer;
  String? sourceSequence;

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

  runReplicationCycle() async {
    if (running) {
      return;
    } else {
      running = true;
      try {
        int untilIndex = min(limit, dbChanges.length);
        List<ChangeResult> toProcess = dbChanges.sublist(0, untilIndex);
        this.sourceSequence =
            toProcess.isNotEmpty ? toProcess.last.seq : sourceInfo!.updateSeq;
        dbChanges.removeRange(0, untilIndex);
        onData(toProcess);

        Map<String, List<String>> changes = await readBatchOfChanges(toProcess);
        onData(changes);

        Map<String, RevsDiff> revsDiff =
            await calculateRevisionDifference(changes);
        onData(revsDiff);

        if (revsDiff.isNotEmpty) {
          List<Doc<Map<String, dynamic>>> docs =
              await fetchChangedDocuments(revsDiff: revsDiff, changes: changes);
          onData(docs);

          BulkDocResponse bulkDocResponse = await target.lock.synchronized(
              () async => await uploadBatchOfChangedDocuments(body: docs));
          onData(bulkDocResponse);

          if (bulkDocResponse.error == null) {
            EnsureFullCommitResponse ensureFullCommitResponse =
                await target.ensureFullCommit();
            onData(ensureFullCommitResponse);

            this.targetInfo = await getTargetInformation();
            onData(targetInfo);

            PutResponse insertResponse = await recordReplicationCheckpoint();
            if (insertResponse.ok == true) {
              onData(insertResponse);
            } else {
              throw ("replication log error: ${insertResponse.error}");
            }
          } else {
            throw ("bulk docs error: ${bulkDocResponse.error}");
          }
        } else {
          this.targetInfo = await getTargetInformation();
          onData(targetInfo);

          PutResponse insertResponse = await recordReplicationCheckpoint();
          if (insertResponse.ok == true) {
            onData(insertResponse);
          } else {
            throw ("replication log error: ${insertResponse.error}");
          }
        }
        onData("One Cycle Completed");
      } catch (err) {
        running = false;
        //print(err);
        throw err;
      } finally {
        running = false;
      }
    }
  }

  listenToNormalChanges({required String since, required String upperbound}) {
    try {
      int upperboundInt = int.parse(upperbound.split('-')[0]);
      listenToChangesFeed(feed: ChangeFeed.normal, since: since)
          .then((value) async {
        value.onResult((changeResult) => dbChanges.add(changeResult));
        value.onComplete((changeResponse) async {
          try {
            bool complete = false;
            if (int.parse(changeResponse.lastSeq!.split('-')[0]) >=
                upperboundInt) {
              complete = true;
              dbChanges = dbChanges
                  .where((element) =>
                      int.parse(element.seq.split('-')[0]) <= upperboundInt)
                  .toList();
            }

            await runReplicationCycle();

            if (changeResponse.pending == 0 || complete == true)
              this.onComplete!("Completed");
            else {
              sourceInfo = await getSourceInformation();
              listenToNormalChanges(
                  since: changeResponse.lastSeq!, upperbound: upperbound);
              value.cancel();
            }
          } catch (error) {
            onError(Exception(error), () {
              cancel();
              listenToNormalChanges(since: since, upperbound: upperbound);
            });
          }
        });
      });
    } catch (error) {
      onError(Exception(error), () {
        cancel();
        listenToNormalChanges(since: since, upperbound: upperbound);
      });
    }
  }

  listenToContinuousChanges({required String since}) {
    try {
      listenToChangesFeed(feed: ChangeFeed.continuous, since: since)
          .then((value) async {
        this.onCancel = value.cancel;
        value.onResult((changeResult) {
          try {
            dbChanges.add(changeResult);
            if (dbChanges.length == limit) {
              runReplicationCycle();
            }
          } catch (error) {
            cancel();
            onError(Exception(error),
                () => listenToContinuousChanges(since: since));
          }
        });
      });

      this.timer = Timer.periodic(timeout, (timer) {
        try {
          if (dbChanges.length > 0) runReplicationCycle();
        } catch (e) {
          cancel();
          onError(Exception(e), () => listenToContinuousChanges(since: since));
        }
      });
    } catch (error) {
      cancel();
      onError(Exception(error), () => listenToContinuousChanges(since: since));
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
        listenToContinuousChanges(since: sourceLastSeq);
      } else
        listenToNormalChanges(
            since: sourceLastSeq, upperbound: sourceInfo?.updateSeq ?? "0");
    } catch (e) {
      onError(Exception(e), () => replicate(onData: onData, onError: onError));
    }
  }

  cancel() {
    this.timer!.cancel();
    this.onCancel!();
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
    return replicationID;
  }

  Future<Doc<ReplicationLog>?> retrieveReplicationLog() async {
    return await target.get(
        id: "_local/2b93a1dd-c17f-4422-addd-d432c5ae39c6",
        fromJsonT: (json) =>
            ReplicationLog.fromJson(jsonDecode(jsonEncode(json))));
  }

  Future<ChangesStream> listenToChangesFeed(
      {required String feed, required String since}) async {
    return source.changesStream(ChangeRequest(
        feed: feed,
        style: 'all_docs',
        heartbeat: 10000,
        since: since,
        limit: live ? limit : null));
  }

  Future<Map<String, List<String>>> readBatchOfChanges(
      List<ChangeResult> changeResults) async {
    Map<String, List<String>> changes = new Map();
    changeResults.reversed.forEach((changeResult) {
      if (changes.containsKey(changeResult.id)) {
        if (changes[changeResult.id]?[0].split('-')[0] ==
            changeResult.changes[0].rev.split('-')[0]) {
          changes[changeResult.id]?.add(changeResult.changes[0].rev);
        }
      } else {
        changes.putIfAbsent(
            changeResult.id, () => [changeResult.changes[0].rev]);
      }
    });
    return changes;
  }

  Future<Map<String, RevsDiff>> calculateRevisionDifference(
      Map<String, List<String>> body) async {
    return await target.revsDiff(body: body);
  }

  //open revs == line[3] only? // missing value = null docs - take any action?? //object to map<String,dynamic> (value)
  Future<List<Doc<Map<String, dynamic>>>> fetchChangedDocuments(
      {required Map<String, RevsDiff> revsDiff,
      required Map<String, List<String>> changes}) async {
    List<Doc<Map<String, dynamic>>> bulkDocs = [];

    for (final entry in revsDiff.entries) {
      Doc<Map<String, dynamic>>? doc = await source.get(
          id: entry.key,
          openRevs: changes[entry.key],
          revs: true,
          latest: true,
          fromJsonT: (value) {
            Map<String, dynamic> map = jsonDecode(jsonEncode(value));
            map.remove("_id");
            map.remove("_rev");
            map.remove("_revisions");
            return map;
          });
      if (doc != null) {
        bulkDocs.add(doc);
      }
    }

    return bulkDocs;
  }

  Future<BulkDocResponse> uploadBatchOfChangedDocuments(
      {required List<Doc<Map<String, dynamic>>> body}) async {
    BulkDocResponse bulkDocResponse = await target.bulkDocs(body: body);
    return bulkDocResponse;
  }

  Future<PutResponse> recordReplicationCheckpoint() async {
    replicationLog = new Doc(
        id: "_local/$replicationID",
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

    Doc<Map<String, dynamic>> newReplicationLog =
        Doc<Map<String, dynamic>>.fromJson(
            replicationLog!.toJson((value) => value.toJson()),
            (value) => jsonDecode(jsonEncode(value))["model"]);

    PutResponse putResponse = await target.put(doc: newReplicationLog);
    return putResponse;
  }
}
