import 'dart:async';
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
  ReplicationLog? replicationLog;
  String? replicationId;
  StreamSubscription? streamSubscription;

  StreamController _streamController = new StreamController<dynamic>();

  void dispose() {
    _streamController.close();
  }

  Replicator({required this.source, required this.target});

  Future<void> executeReplication(String? type) async {
    this.sourceInfo = await getSourceInformation();
    _streamController.add(sourceInfo);

    this.targetInfo = await getTargetInformation();
    _streamController.add(targetInfo);

    this.replicationId = await generateReplicationID();
    _streamController.add(replicationID);

    this.replicationLog = await retrieveReplicationLog();
    _streamController.add(replicationLog);

    streamSubscription = (await listenToChangesFeed()).listen((event) async {
      _streamController.add(event);

      Map<String, List<String>> changes = await readBatchOfChanges(event);
      _streamController.add(changes);

      Map<String, RevsDiff> revsDiff =
          await calculateRevisionDifference(changes);
      _streamController.add(revsDiff);

      if (revsDiff.isNotEmpty) {
        List<Doc> docs = await fetchChangedDocuments(revsDiff: revsDiff);
        _streamController.add(docs);

        BulkDocResponse bulkDocResponse =
            await target.lock.synchronized(() async {
          return await uploadBatchOfChangedDocuments(body: docs);
        });
        _streamController.add(bulkDocResponse);

        if (bulkDocResponse.error == null) {
          EnsureFullCommitResponse ensureFullCommitResponse =
              await target.ensureFullCommit();
          _streamController.add(ensureFullCommitResponse);

          PutResponse insertResponse = await recordReplicationCheckpoint();
          if (insertResponse.ok) {
            _streamController.add(insertResponse);
            if (type == 'normal') _streamController.close();
          } else {
            _streamController.addError('replication log insertion failure');
          }
        } else {
          _streamController.addError('bulk docs insertion failure');
        }
      } else {
        PutResponse insertResponse = await recordReplicationCheckpoint();
        if (insertResponse.ok) {
          _streamController.add(insertResponse);
          if (type == 'normal') _streamController.close();
        } else {
          _streamController.addError('replication log insertion failure');
        }
      }
      if (type == 'normal') streamSubscription!.cancel();
    })
      ..onError((e) {
        _streamController.addError(e);
      });
  }

  Future<Stream<dynamic>> replicate({String? type}) async {
    executeReplication(type ?? 'normal');
    return _streamController.stream;
  }

  void stopReplication() {
    streamSubscription?.cancel();
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

  Future<ReplicationLog?> retrieveReplicationLog() async {
    return await target.getReplicationLog(id: this.replicationId!);
  }

  Future<Stream<ChangeResponse>> listenToChangesFeed() async {
    return source.changesStream(ChangeRequest(
        feed: 'normal',
        descending: true,
        style: 'all_docs',
        heartbeat: 10000,
        since: this.replicationLog?.sourceLastSeq ?? '0'));
  }

  Future<Map<String, List<String>>> readBatchOfChanges(
      ChangeResponse changeResponse) async {
    Map<String, List<String>> changes = new Map();
    changeResponse.results.forEach((changeResult) {
      changes.putIfAbsent(changeResult.id, () => []);
      changes[changeResult.id]!
          .addAll(changeResult.changes.map((e) => e.rev).toList());
    });

    return changes;
  }

  Future<Map<String, RevsDiff>> calculateRevisionDifference(
      Map<String, List<String>> body) async {
    return await target.revsDiff(body: body);
  }

  Future<List<Doc>> fetchChangedDocuments(
      {required Map<String, RevsDiff> revsDiff}) async {
    List<Doc> bulkDocs = new List.from([]);
    revsDiff.forEach((key, value) async {
      Doc? doc = await source.get(id: key, revs: true, latest: true);
      if (doc != null) {
        bulkDocs.add(doc);
      }
    });
    return bulkDocs;
  }

  Future<BulkDocResponse> uploadBatchOfChangedDocuments(
      {required List<Doc> body}) async {
    BulkDocResponse bulkDocResponse = await target.bulkDocs(body: body);
    return bulkDocResponse;
  }

  Future<PutResponse> recordReplicationCheckpoint() async {
    PutResponse putResponse =
        await target.putReplicationLog(id: this.replicationId!, body: {
      '_rev': this.replicationLog?.rev,
      'history': [
        {
          "recorded_seq": this.targetInfo!.updateSeq,
          "start_time": this.sourceInfo!.instanceStartTime,
          "end_time": this.targetInfo!.instanceStartTime
        }
      ],
      "replication_id_version":
          this.replicationLog?.replicationIdVersion ?? 0 + 1,
      "session_id": uuidGenerator.v4(),
      "source_last_seq": this.sourceInfo!.updateSeq
    });

    return putResponse;
  }
}
