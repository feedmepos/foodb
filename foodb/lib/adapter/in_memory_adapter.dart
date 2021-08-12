import 'dart:async';

import 'package:foodb/adapter/exception.dart';
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

import 'adapter.dart';

typedef Store = String;
typedef StoreObject = Map<String, dynamic>;
typedef Stores = Map<Store, StoreObject>;

class MemoryAdapter extends AbstractAdapter {
  MemoryAdapter({required dbName})
      : _stores = Stores(),
        super(dbName: dbName);

  final Stores _stores;

  Store get docDbName => '${dbName}_doc';

  Store get viewDbName => '${dbName}_view';

  Store get changesDbName => '${dbName}_changes';

  StoreObject? get docsDb => _stores[docDbName];

  StoreObject? get changesDb => _stores[changesDbName];

  StoreObject? get viewsDb => _stores[viewDbName];

  int? get docCount => docsDb?.length;

  void _put(Store store, {required String id, dynamic object, String? newRev}) {
    if (object == null)
      throw AdapterException(error: 'object is required for put method');
    var storeRecords = _stores[store];
    if (storeRecords == null) {
      _stores.putIfAbsent(store, () => {id: object});
    } else {
      storeRecords.update(id, (value) => object, ifAbsent: () => object);
    }
  }

  bool _delete(Store store, {required String id}) {
    var records = _stores[store];
    if (records != null) {
      _stores[store]?.removeWhere((key, value) => key == id);
      return true;
    } else {
      return false;
    }
  }

  dynamic _find(Store store, {required String id}) => _stores[store]?[id];

  void _updateChanges({required String id, required String rev}) {
    var changes = changesDb;
    if (changes == null) {
    } else {
      var result = _find(changesDbName, id: id);
      if (result) {
        var changeObject =
            ChangeResult.fromJson(result as Map<String, dynamic>);
        changesDb?.update(id, (value) => ChangeResult(id: id, seq: seq, changes: changeObject.changes).toJson());
      }
    }
  }

  @override
  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    if (docCount == null)
      throw AdapterException(error: 'Documents store is not yet created');
    return GetAllDocs(
        offset: 0,
        totalRows: 0,
        rows: docsDb!.entries
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
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = false}) async {
    body.forEach((element) =>
        _put(docDbName, id: element.id, object: element.toJson((v) => v)));
    return BulkDocResponse(
        putResponses:
            body.map((e) => PutResponse(ok: true, id: e.id)).toList());
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
  Future<DeleteResponse> delete(
      {required String id, required String rev}) async {
    return DeleteResponse.fromJson(
        DeleteResponse(ok: _delete(docDbName, id: id), id: id, rev: rev)
            .toJson());
  }

  @override
  Future<bool> destroy() async {
    _stores.clear();
    return true;
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
  Future<FindResponse> find(FindRequest findRequest) async {
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
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    var result = _find(docDbName, id: id);
    return result != null
        ? Doc<T>.fromJson(
            result, (json) => fromJsonT(json as Map<String, dynamic>))
        : null;
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
      String? newRev}) async {
    _put(docDbName, id: doc.id, object: doc.toJson((value) => value));
    return PutResponse.fromJson(PutResponse(ok: true).toJson());
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) {
    // TODO: implement revsDiff
    throw UnimplementedError();
  }
}
