import 'dart:async';
import 'dart:collection';

import 'package:foodb/adapter/exception.dart';
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
import 'package:foodb/adapter/utils.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';

import 'adapter.dart';

typedef Store = String;
typedef StoreObject = SplayTreeMap<String, dynamic>;
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

  late String lastSeq;

  void _put(Store store, {required String id, dynamic object, String? newRev}) {
    if (object == null)
      throw AdapterException(error: 'object is required for put method');
    var storeRecords = _stores[store];
    if (storeRecords == null) {
      _stores.putIfAbsent(store, () => StoreObject.from({id: object}));
    } else {
      storeRecords.update(id, (value) => object, ifAbsent: () => object);
    }
  }

  bool _delete(Store store, {required String id}) {
    var result = _find(store, id: id);
    if (result != null) {
      _stores[store]?.remove(id);
      return true;
    } else {
      return false;
    }
  }

  dynamic _find(Store store, {required String id}) => _stores[store]?[id];

  void _updateChanges({required String id, required String rev}) {
    var changes = changesDb;
    // changes store is not yet initialized
    // seq can start with 1
    if (changes == null) {
      lastSeq = SequenceTool.generate();
      _stores.putIfAbsent(
          changesDbName,
          () => StoreObject.from({
                id: ChangeResult(
                    id: id,
                    seq: lastSeq,
                    changes: [ChangeResultRev(rev: rev)]).toJson()
              }));
    } else {
      lastSeq = SequenceTool(lastSeq).increment();

      /// to do changes list toJson fix
      changesDb?.update(
          id,
          (value) => ChangeResult(id: id, seq: lastSeq, changes: [
                ChangeResultRev(rev: rev)
              ]).toJson(),
          ifAbsent: () => ChangeResult(
              id: id,
              seq: lastSeq,
              changes: [ChangeResultRev(rev: rev)]).toJson());
    }
  }

  @override
  // Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
  //     T Function(Map<String, dynamic> json) fromJsonT) async {
  //   if (docCount == null)
  //     throw AdapterException(error: 'Documents store is not yet created');
  //   return GetAllDocs(
  //       offset: 0,
  //       totalRows: 0,
  //       rows: docsDb!.entries
  //           .map((e) => Row<T>(
  //               id: e.key,
  //               key: e.key,
  //               value: Value(rev: e.value['_rev']),
  //               doc: allDocsRequest.includeDocs
  //                   ? Doc.fromJson(
  //                       e.value, (e) => fromJsonT(e as Map<String, dynamic>))
  //                   : null))
  //           .toList());
  // }

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
    var result = _find(docDbName, id: doc.id);
    var rev = newEdits ? doc.rev ?? RevisionTool.generate() : newRev;
    var newDoc = doc.toJson((value) => value);
    // first revision
    if (result == null) {
      newDoc['_rev'] = newEdits ? RevisionTool.generate() : newRev;
      _put(docDbName, id: doc.id, object: newDoc);
    } else {
      var resultObject = Doc.fromJson(result, (json) => json);
      if (!newEdits) {
        var body = doc.model;

        if (newRev == null) {
          throw new AdapterException(
              error: 'newRev is required when newEdits is false');
        }
        body['_revisions'] = {
          "ids": doc.rev == null
              ? [RevisionTool(newRev).content]
              : [RevisionTool(newRev).content, RevisionTool(doc.rev!).content],
          "start": int.parse(newRev.split('-')[0])
        };
        newDoc['model'] = body;
        newDoc['_rev'] = newRev;
        _put(docDbName, id: doc.id, object: newDoc);
      } else {
        newDoc['_rev'] = RevisionTool(resultObject.rev!).increment();
        _put(docDbName, id: doc.id, object: newDoc);
      }
    }
    _updateChanges(id: doc.id, rev: rev!);
    return PutResponse.fromJson(PutResponse(ok: true).toJson());
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) {
    // TODO: implement revsDiff
    throw UnimplementedError();
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) {
    // TODO: implement explain
    throw UnimplementedError();
  }

  @override
  Future<Doc<DesignDoc>?> fetchDesignDoc({required String id}) {
    // TODO: implement fetchDesignDoc
    throw UnimplementedError();
  }

  @override
  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic> p1) toJsonT) {
    // TODO: implement find
    throw UnimplementedError();
  }

  @override
  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) {
    // TODO: implement allDocs
    throw UnimplementedError();
  }
}
