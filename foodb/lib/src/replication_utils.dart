import 'dart:convert';
import 'dart:math';


import 'package:crypto/crypto.dart';
import 'package:foodb/foodb.dart';

final replicatorVersion = 1;

class WhereFunction<T> {
  final String id;
  final bool Function(T) whereFn;
  WhereFunction(this.id, this.whereFn);
  bool call(T val) {
    return whereFn(val);
  }
}

class ReplicationCheckpoint {
  Doc<ReplicationLog> log;
  List<ChangeResult> processed;
  List<ChangeResult> replicated;
  ReplicationCheckpoint({
    required this.replicated,
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

String generateReplicationId(
    {String? sourceUuid,
      String? sourceUri,
      String? targetUuid,
      String? targetUri,
      bool? createTarget,
      bool? continuous,
      Map<String, String>? headers,
      String? filter,
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
    filter ?? "",
    params?.toString() ?? ""
  ].join()))
      .toString();
}


parseSeqInt(String seq) {
  return int.tryParse(seq.split('-')[0]) ?? 0;
}


Future<Doc<ReplicationLog>> retriveReplicationLog(Foodb db, replicationId) async {
  final id = "_local/$replicationId";

  try {
    return await db.get(
        id: "_local/$replicationId",
        fromJsonT: (json) => ReplicationLog.fromJson(json));
  } on AdapterException catch (ex) {
    FoodbDebug.debug(ex.toString());
    if (ex.error.contains('not_found')) {
      return Doc(
        id: id,
        model: ReplicationLog(
          history: [],
          replicationIdVersion: 1,
          sessionId: "",
          sourceLastSeq: "0",
        ),
      );
    }
    rethrow;
  }
}

Future<Doc<ReplicationLog>> setReplicationCheckpoint(
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
