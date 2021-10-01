library foodb;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:foodb/common.dart';
import 'package:foodb/design_doc.dart';
import 'package:foodb/exception.dart';
import 'package:foodb/key_value/common.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb/methods/bulk_docs.dart';
import 'package:foodb/methods/bulk_get.dart';
import 'package:foodb/methods/changes.dart';
import 'package:foodb/methods/delete.dart';
import 'package:foodb/methods/ensure_full_commit.dart';
import 'package:foodb/methods/explain.dart';
import 'package:foodb/methods/find.dart';
import 'package:foodb/methods/index.dart';
import 'package:foodb/methods/info.dart';
import 'package:foodb/methods/put.dart';
import 'package:foodb/methods/revs_diff.dart';
import 'package:foodb/methods/server.dart';
import 'package:foodb/methods/view.dart';
import 'package:http/http.dart' as http;
import 'package:uri/uri.dart';

export 'package:foodb/common.dart';
export 'package:foodb/design_doc.dart';
export 'package:foodb/exception.dart';
export 'package:foodb/in_memory_adapter.dart';
export 'package:foodb/methods/bulk_docs.dart';
export 'package:foodb/methods/bulk_get.dart';
export 'package:foodb/methods/changes.dart';
export 'package:foodb/methods/delete.dart';
export 'package:foodb/methods/ensure_full_commit.dart';
export 'package:foodb/methods/explain.dart';
export 'package:foodb/methods/find.dart';
export 'package:foodb/methods/index.dart';
export 'package:foodb/methods/info.dart';
export 'package:foodb/methods/put.dart';
export 'package:foodb/methods/revs_diff.dart';
export 'package:foodb/methods/server.dart';
export 'package:foodb/methods/view.dart';

export 'foodb.dart';

part 'couchdb.dart';
part 'key_value/key_value_changes.dart';
part 'key_value/key_value_find.dart';
part 'key_value/key_value_get.dart';
part 'key_value/key_value_put.dart';
part 'key_value/key_value_util.dart';
part 'key_value/key_value_view.dart';

abstract class Foodb {
  String dbName;
  Foodb({required this.dbName});

  factory Foodb.couchdb({required String dbName, required Uri baseUri}) {
    return _Couchdb(dbName: dbName, baseUri: baseUri);
  }

  factory Foodb.keyvalue(
      {required String dbName, required KeyValueAdapter keyValueDb}) {
    return _KeyValue(dbName: dbName, keyValueDb: keyValueDb);
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
      {required List<Doc<Map<String, dynamic>>> body, bool newEdits = true});

  Future<EnsureFullCommitResponse> ensureFullCommit();

  Future<ChangesStream> changesStream(ChangeRequest request);

  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT);

  Future<IndexResponse> createIndex(
      {required QueryViewOptionsDef index,
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
      String viewId,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT);
}

abstract class JSRuntime {
  evaluate(String script);
}

String getViewName({required String designDocId, required String viewId}) {
  return '_design/${designDocId}/_view/$viewId';
}

const String allDocDesignDocId = "all_docs";
const String allDocViewId = "all_docs";
final String allDocViewName =
    getViewName(designDocId: allDocDesignDocId, viewId: allDocViewId);

final allDocDesignDoc = new Doc(
    id: "all_docs",
    model: DesignDoc(
        language: 'query', views: {"all_docs": AllDocDesignDocView()}));

abstract class _AbstractKeyValue extends Foodb {
  KeyValueAdapter keyValueDb;
  JSRuntime? jsRuntime;

  StreamController<MapEntry<SequenceKey, UpdateSequence>>
      localChangeStreamController = StreamController.broadcast();

  @override
  String get dbUri => '${this.keyValueDb.type}://${this.dbName}';

  _AbstractKeyValue({required dbName, required this.keyValueDb, this.jsRuntime})
      : super(dbName: dbName);

  encodeSeq(int seq) {
    return '$seq-0';
  }

  decodeSeq(String seq) {
    return int.parse(seq.split('-')[0]);
  }
}

class _KeyValue extends _AbstractKeyValue
    with
        _KeyValueGet,
        _KeyValueFind,
        _KeyValueUtil,
        _KeyValuePut,
        _KeyValueChange,
        _KeyValueView {
  _KeyValue(
      {required dbName,
      required KeyValueAdapter keyValueDb,
      JSRuntime? jsRuntime})
      : super(dbName: dbName, keyValueDb: keyValueDb, jsRuntime: jsRuntime);
}

timed(String step, Function fn) async {
  Stopwatch stopwatch = Stopwatch();
  stopwatch.reset();
  stopwatch.start();
  await fn();
  stopwatch.stop();
  print('$step: ${stopwatch.elapsed.inMilliseconds}ms');
}
