import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/all_docs.dart';

abstract class KeyValueAdapter extends AbstractAdapter {
  KeyValueAdapter({required dbName}) : super(dbName: dbName);

  Future<bool> _put(String store, String key, Map<String, dynamic> value);
  Future<bool> _delete(String store, String key);
  Future<Map<String, Map<String, dynamic>>> _read(String store,
      {String? startKey, String? endKey, bool? desc});

  @override
  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var data = await _read('all_docs_view',
        startKey: allDocsRequest.startKey,
        endKey: allDocsRequest.endKey,
        desc: allDocsRequest.descending);
    return GetAllDocs(
        offset: 0,
        totalRows: 0,
        rows: data.entries
            .map((e) => Row<T>(
                id: e.key,
                key: e.key,
                value: Value(rev: e.value['_rev']),
                doc: allDocsRequest.includeDocs
                    ? Doc.fromJson(
                        e.value, (e) => fromJsonT(e as Map<String, dynamic>))
                    : null))
            .toList());
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body, bool newEdits = false}) {
    // TODO: implement bulkDocs
    throw UnimplementedError();
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) {
    // TODO: implement changesStream
    throw UnimplementedError();
  }

  @override
  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      Map<String, Object>? partialFilterSelector}) {
    // TODO: implement createIndex
    throw UnimplementedError();
  }

  @override
  Future<DeleteResponse> delete({required String id, required String rev}) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<bool> destroy() {
    // TODO: implement destroy
    throw UnimplementedError();
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() {
    // TODO: implement ensureFullCommit
    throw UnimplementedError();
  }

  @override
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
      required T Function(Map<String, dynamic> json) fromJsonT}) {
    // TODO: implement fetchChanges
    throw UnimplementedError();
  }

  @override
  Future<FindResponse> find(FindRequest findRequest) {
    // TODO: implement find
    throw UnimplementedError();
  }

  @override
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
      required T Function(Object? json) fromJsonT}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<GetInfoResponse> info() {
    // TODO: implement info
    throw UnimplementedError();
  }

  @override
  Future<bool> init() {
    // TODO: implement init
    throw UnimplementedError();
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc,
      bool newEdits = true,
      String? newRev}) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) {
    // TODO: implement revsDiff
    throw UnimplementedError();
  }
}
