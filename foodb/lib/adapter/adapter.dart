import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/replication.dart';
import 'package:synchronized/synchronized.dart';

class ChangeFeed {
  static final continuous = "continuous";
  static final longpoll = "longpoll";
  static final normal = "normal";
}

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
      // Object? openRevs,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT});

  Future<Doc<DesignDoc>?> fetchDesignDoc({required String id});

  Future<List<Doc<DesignDoc>>> fetchAllDesignDocs();

  Future<List<Doc<T>>> fetchChanges<T>(
      {required String id,
      bool attachments = false,
      bool attEncodingInfo = false,
      List<String>? attsSince,
      bool conflicts = false,
      bool deletedConflicts = false,
      bool latest = false,
      bool localSeq = false,
      bool meta = false,
      required Object openRevs,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT});

  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc,
      bool newEdits = true,
      String? newRev});

  Future<DeleteResponse> delete({required String id, required String rev});

  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body});

  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body, bool newEdits = false});

  Future<EnsureFullCommitResponse> ensureFullCommit();

  Future<ChangesStream> changesStream(ChangeRequest request);
  // Future<Stream<String>> changesStreamString(ChangeRequest request);

  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT);

  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      Map<String, Object>? partialFilterSelector});

  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic>) toJsonT);

  Future<ExplainResponse> explain(FindRequest findRequest);

  Future<bool> init();
  Future<bool> destroy();
}
