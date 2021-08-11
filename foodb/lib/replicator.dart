import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
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
  Map<String, StreamSubscription> onResultSubscriptions = {};
  Map<String, StreamSubscription> onCompleteSubscriptions = {};
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

  runReplicationCycle(String since, String? upperbound) async {
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
        dbChanges.removeRange(0, untilIndex);
        onData("One Cycle Completed");
        if (!this.live && this.complete!) {
          if (dbChanges.length == 0) {
            this.onComplete!("Completed");
          } else {
            runReplicationCycle(since, upperbound);
          }
        }
      } catch (err) {
        this.running = false;
        // this.cancel(since);
        // this.onError(Exception(err), () {
        //   live
        //       ? listenToContinuousChanges(since: since)
        //       : listenToNormalChanges(since: since, upperbound: upperbound!);
        // });
        throw err;
      } finally {
        this.running = false;
      }
    }
  }

  listenToNormalChanges({required String since, required String upperbound}) {
    try {
      int upperboundInt = int.parse(upperbound.split('-')[0]);
      listenToChangesFeed(feed: ChangeFeed.normal, since: since)
          .then((value) async {
        this.onCancels[since] = value.cancel;
        StreamSubscription onResultSubscription =
            value.onResult((changeResult) => dbChanges.add(changeResult));
        StreamSubscription onCompleteSubscription =
            value.onComplete((changeResponse) async {
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
            await runReplicationCycle(since, upperbound);

            if (!complete!) {
              sourceInfo = await getSourceInformation();
              this.cancel(since);
              listenToNormalChanges(
                  since: changeResponse.lastSeq!, upperbound: upperbound);
            }
          } catch (error) {
            this.cancel(since);
            onError(Exception(error), () {
              listenToNormalChanges(since: since, upperbound: upperbound);
            });
          }
        });

        onCompleteSubscriptions[since] = onCompleteSubscription;
        onResultSubscriptions[since] = onResultSubscription;
      });
    } catch (error) {
      this.cancel(since);
      onError(Exception(error), () {
        listenToNormalChanges(since: since, upperbound: upperbound);
      });
    }
  }

  listenToContinuousChanges({required String since}) {
    try {
      listenToChangesFeed(feed: ChangeFeed.continuous, since: since)
          .then((value) async {
        this.onCancels[since] = value.cancel;
        StreamSubscription onResultSubscription =
            value.onResult((changeResult) {
          try {
            dbChanges.add(changeResult);
            if (dbChanges.length == limit) {
              runReplicationCycle(since, "");
            }
          } catch (error) {
            this.cancel(since);
            this.onError(Exception(error),
                () => listenToContinuousChanges(since: since));
          }
        });
        this.onResultSubscriptions[since] = onResultSubscription;
      });

      this.timer = Timer.periodic(timeout, (timer) {
        try {
          if (dbChanges.length > 0) runReplicationCycle(since, "");
        } catch (e) {
          this.cancel(since);
          this.onError(
              Exception(e), () => listenToContinuousChanges(since: since));
        }
      });
    } catch (error) {
      this.cancel(since);
      this.onError(
          Exception(error), () => listenToContinuousChanges(since: since));
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
      this.onError(
          Exception(e), () => replicate(onData: onData, onError: onError));
    }
  }

  cancel(String since) {
    this.onResultSubscriptions[since]?.cancel();
    this.onResultSubscriptions.remove(since);

    this.onCompleteSubscriptions[since]?.cancel();
    if (!live) this.onCompleteSubscriptions.remove(since);

    this.timer?.cancel();
    if (this.onCancels.containsKey(since)) this.onCancels[since]!();
    this.onCancels.remove(since);
  }

  cancelStream() {
    this.onResultSubscriptions.forEach((key, value) {
      value.cancel();
    });
    this.onResultSubscriptions.clear();
    this.onCompleteSubscriptions.forEach((key, value) {
      value.cancel();
    });

    this.timer?.cancel();
    this.onCancels.forEach((key, value) {
      value();
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
        conflicts: true,
        limit: !live ? limit : null));
  }

  Future<Map<String, List<String>>> readBatchOfChanges(
      List<ChangeResult> changeResults) async {
    Map<String, List<String>> changes = new Map();
    changeResults.reversed.forEach((changeResult) {
      print(changeResult.id);
      if (changes.containsKey(changeResult.id)) {
        if (changes[changeResult.id]?[0].split('-')[0] ==
            changeResult.changes[0].rev.split('-')[0]) {
          changes[changeResult.id]?.add(changeResult.changes[0].rev);
        }
      } else {
        List<String> revs = [changeResult.changes[0].rev];
        if (changeResult.changes.length > 1) {
          for (int i = 1; i < changeResult.changes.length; i++) {
            if (int.parse(changeResult.changes[i].rev.split('-')[0]) ==
                int.parse(revs.first.split('-')[0])) {
              revs.add(changeResult.changes[i].rev);
            }
          }
        }
        changes.putIfAbsent(changeResult.id, () => revs);
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

    for (final key in revsDiff.keys) {
      List<Doc<Map<String, dynamic>>> docs = await source.fetchChanges(
          id: key,
          openRevs: changes[key]!,
          revs: true,
          latest: true,
          fromJsonT: (value) {
            value.remove("_id");
            value.remove("_revisions");
            value.remove("_rev");
            return value;
          });

      bulkDocs.addAll(docs);
    }

    return bulkDocs;
  }

  Future<BulkDocResponse> uploadBatchOfChangedDocuments(
      {required List<Doc<Map<String, dynamic>>> body}) async {
    BulkDocResponse bulkDocResponse =
        await target.bulkDocs(body: body, newEdits: false);
    return bulkDocResponse;
  }

  Future<PutResponse> recordReplicationCheckpoint() async {
    replicationLog = new Doc(
        id: "_local/$replicationID",
        // rev: "1-0",
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
            (value) => (value as Map<String, dynamic>)["model"]);

    PutResponse putResponse = await target.put(doc: newReplicationLog);

    return putResponse;
  }
}
