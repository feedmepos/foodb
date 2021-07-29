import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/replication.dart';
import 'package:synchronized/synchronized.dart';

abstract class AbstractAdapter {
  var _lock = new Lock();
  Lock get lock => _lock;

  String dbName;
  AbstractAdapter({required this.dbName});

  Future<GetInfoResponse> info();

  Future<Doc<T>?> get<T>(
      {required String id,
      bool attachments = false,
      bool attEncodingInfo = false,
      List<String>? attsSince,
      bool conflicts = false,
      bool deletedConflicts = false,
      bool latest = false,
      bool localSeq = false,
      bool meta = false,
      Object? openRevs,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Object? json) fromJsonT});

  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> body,
      bool newEdits = true,
      String? newRev});

  Future<DeleteResponse> delete({required String id, required String rev});

  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body});

  Future<BulkDocResponse> bulkDocs<T>(
      {required List<Doc<T>> body, required Object? Function(T value) toJsonT});

  Future<EnsureFullCommitResponse> ensureFullCommit();

  Future<Stream<ChangeResponse>> changesStream(ChangeRequest request);

  Future<PutResponse> putReplicationLog(
      {required String id, required Map<String, dynamic> body});

  Future<ReplicationLog?> getReplicationLog({required String id});

  Future<GetAllDocs<T>> allDocs<T>(
      GetAllDocsRequest allDocsRequest, T Function(Object? json) fromJsonT);

  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      Map<String, Object>? partialFilterSelector});

  Future<FindResponse> find(FindRequest findRequest);
}
