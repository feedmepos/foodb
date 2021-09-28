import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/key_value/in_memory_database.dart';
import 'package:foodb/adapter/key_value/key_value_adapter.dart';
import 'package:foodb/adapter/key_value/key_value_database.dart';
// import 'package:foodb/adapter/key_value/key_value_adapter.dart';
// import 'package:foodb/adapter/key_value/key_value_database.dart';
import 'package:foodb/adapter/methods/view.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/server.dart';
import 'package:foodb/adapter/methods/open_revs.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';

export 'foodb.dart';
export './common/doc.dart';
export './common/design_doc.dart';
export './common/rev.dart';
export 'adapter/methods/view.dart';
export './adapter/methods/bulk_docs.dart';
export './adapter/methods/changes.dart';
export './adapter/methods/delete.dart';
export './adapter/methods/ensure_full_commit.dart';
export './adapter/methods/explain.dart';
export './adapter/methods/find.dart';
export './adapter/methods/index.dart';
export './adapter/methods/info.dart';
export './adapter/methods/open_revs.dart';
export './adapter/methods/put.dart';
export './adapter/methods/revs_diff.dart';
export 'adapter/couchdb_adapter.dart';

class ChangeFeed {
  static final continuous = "continuous";
  static final longpoll = "longpoll";
  static final normal = "normal";
}

abstract class Foodb {
  String dbName;
  Foodb({required this.dbName});

  factory Foodb.couchdb({required String dbName, required Uri baseUri}) {
    return CouchdbAdapter(dbName: dbName, baseUri: baseUri);
  }

  factory Foodb.inMemoryDb({required String dbName}) {
    return KeyValueAdapter(dbName: dbName, keyValueDb: InMemoryDatabase());
  }

  String get dbUri;

  Future<GetServerInfoResponse> serverInfo();
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

  Future<List<Doc<T>>> getWithOpenRev<T>(
      {required String id,
      bool attachments = false,
      bool attEncodingInfo = false,
      List<String>? attsSince,
      bool conflicts = false,
      bool deletedConflicts = false,
      bool latest = false,
      bool localSeq = false,
      bool meta = false,
      required OpenRevs openRevs,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT});

  Future<Doc<DesignDoc>?> fetchDesignDoc({
    required String id,
  }) async {
    return get<DesignDoc>(
        id: id, fromJsonT: (json) => DesignDoc.fromJson(json));
  }

  Future<List<Doc<DesignDoc>>> fetchAllDesignDocs() async {
    GetViewResponse<DesignDoc> docs = await allDocs<DesignDoc>(
        GetViewRequest(
            includeDocs: true, startkey: "_design/", endkey: "_design/\uffff"),
        (json) => DesignDoc.fromJson(json));
    return docs.rows.map<Doc<DesignDoc>>((e) => e.doc!).toList();
  }

  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true});

  Future<DeleteResponse> delete({required String id, required Rev rev});

  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body});

  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT});

  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body, bool newEdits = false});

  Future<EnsureFullCommitResponse> ensureFullCommit();

  Future<ChangesStream> changesStream(ChangeRequest request);

  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT);

  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      bool? partitioned});

  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic>) toJsonT);

  Future<ExplainResponse> explain(FindRequest findRequest);

  Future<bool> initDb();

  Future<bool> destroy();

  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewName,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT);
}
