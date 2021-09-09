import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/cupertino.dart';
import 'package:foodb/adapter/adapter.dart';
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
import 'package:foodb/adapter/methods/open_revs.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/common/update_sequence.dart';
import 'package:foodb/common/view_meta.dart';
import 'package:meta/meta.dart';

enum BatchExecuteType { DELETE, INSERT, UPDATE, PUT }

class ReadResult {
  int totalRows;
  int offset;
  Map<String, dynamic> docs;
  ReadResult({
    required this.totalRows,
    required this.offset,
    required this.docs,
  });
}

abstract class KeyValueDatabaseSession {
  abstract var batch;
}

abstract class KeyValueDatabase {
  Future<List<Object?>> runInSession(Function(KeyValueDatabaseSession session));

  Future<bool> put(String tableName,
      {required key,
      required Map<String, dynamic> object,
      KeyValueDatabaseSession? session});

  Future<bool> delete(String tableName,
      {required key, KeyValueDatabaseSession? session});

  Future<Map<String, dynamic>?> get(String tableName, {required String key});

  Future<MapEntry<String, dynamic>?> last(String tableName);

  Future<MapEntry<int, dynamic>?> lastSequence(String tableName);

  Future<ReadResult> read(String tableName,
      {String? startkey, String? endkey, bool? desc});

  Future<Map<int, dynamic>> readSequence(String tableName,
      {int? startkey, int? endkey, bool? desc});

  Future<int> tableSize(String tableName);

  @protected
  Future<void> batchInsert(String tableName,
      {required key,
      required Map<String, dynamic> object,
      required KeyValueDatabaseSession session});

  @protected
  Future<void> batchUpdate(String tableName,
      {required key,
      required Map<String, dynamic> object,
      required KeyValueDatabaseSession session});
}

abstract class JSRuntime {
  evaluate(String script);
}

class KeyValueAdapter extends AbstractAdapter {
  KeyValueDatabase db;
  JSRuntime? jsRuntime;

  KeyValueAdapter({required dbName, required this.db, this.jsRuntime})
      : super(dbName: dbName);

  String get docTableName => 'foodb_${dbName}_docs';

  String get localDocTableName => 'foodb_${dbName}_';

  String get sequenceTableName => 'foodb_${dbName}_sequences';

  String get viewMetaTableName => 'foodb_${dbName}_viewmeta';

  String viewIdTableName(String viewName) =>
      'foodb_${dbName}_view_id_${viewName}';
  String viewKeyTableName(String viewName) =>
      'foodb_${dbName}_view_key_${viewName}';

  StreamController<UpdateSequence> localChangeStreamController =
      StreamController.broadcast();

  @override
  Future<GetAllDocsResponse<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var viewName = _getViewName(designDocId: '_all_docs', viewId: '_all_docs');

    await _generateView(Doc<DesignDoc>(
        id: '_all_docs',
        model: DesignDoc(views: {'_all_docs': AllDocDesignDocView()})));

    ReadResult result = await db.read(viewKeyTableName(viewName),
        startkey: allDocsRequest.startkey,
        endkey: allDocsRequest.endkey,
        desc: allDocsRequest.descending);

    if ((allDocsRequest.startkey != null &&
            allDocsRequest.startKeyDocId != null) ||
        (allDocsRequest.endkey != null && allDocsRequest.endKeyDocId != null)) {
      result.docs.removeWhere((key, value) =>
          ((allDocsRequest.startKeyDocId ?? "")
                      .compareTo(ViewKey.fromString(key).id) >
                  0 ||
              (allDocsRequest.endKeyDocId ?? "\uffff")
                      .compareTo(ViewKey.fromString(key).id) <
                  0));
    }

    List<AllDocRow<T>> rows = [];
    Iterable<MapEntry<String, dynamic>> filteredResult = result.docs.entries;

    for (var e in filteredResult) {
      var key = ViewKey.fromString(e.key);
      AllDocRow<T> row = AllDocRow<T>(
        id: key.id,
        key: key.key,
        value: AllDocRowValue.fromJson(e.value['v']),
      );
      if (allDocsRequest.includeDocs) {
        DocHistory docs =
            DocHistory.fromJson((await db.get(docTableName, key: key.id))!);
        row.doc = docs.winner!.toDoc<T>(docs.id, fromJsonT);
      }
      rows.add(row);
    }

    return GetAllDocsResponse<T>(
        offset: result.offset, totalRows: result.totalRows, rows: rows);
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = false}) async {
    List<BatchExecuteType> types = [];
    List<PutResponse> putResponses = [];

    List<Object?> result = await db.runInSession((session) async {
      // create updateSequence object
      var newUpdateSeq = (await db.lastSequence(sequenceTableName))?.key ?? 0;

      for (var doc in body) {
        var history = await db.get(docTableName, key: doc.id);
        DocHistory docHistory = history == null
            ? DocHistory(
                id: doc.id, docs: {}, revisions: RevisionTree(nodes: []))
            : DocHistory.fromJson(history);
        var docJson = doc.toJson((value) => value);
        var winnerBeforeUpdate = docHistory.winner;

        // Validation
        _validateUpdate(
            newEdits: newEdits,
            winnerBeforeUpdate: winnerBeforeUpdate,
            inputRev: doc.rev);

        // get new Rev
        Rev newRev = _generateNewRev(
            docToEncode: docJson,
            newEdits: newEdits,
            winnerBeforeUpdate: winnerBeforeUpdate,
            revisions: doc.revisions,
            inputRev: doc.rev);

        // rebuild rivision tree
        RevisionTree newRevisionTreeObject = _rebuildRevisionTree(
            oldReivisions: docHistory.revisions,
            newRev: newRev,
            winnerBeforeUpdate: winnerBeforeUpdate,
            inputRevision: doc.revisions,
            newEdits: newEdits);

        newUpdateSeq = newUpdateSeq + 1;

        // create DocHistory Object
        InternalDoc newDocObject = InternalDoc(
            rev: newRev,
            deleted: doc.deleted ?? false,
            localSeq: newUpdateSeq.toString(),
            data: doc.deleted == true ? {} : doc.model);

        DocHistory newDocHistoryObject = docHistory.copyWith(docs: {
          ...docHistory.docs,
          newDocObject.rev.toString(): newDocObject
        }, revisions: newRevisionTreeObject);

        UpdateSequence newUpdateSeqObject = UpdateSequence(
            id: doc.id,
            seq: newUpdateSeq.toString(),
            winnerRev: newDocHistoryObject.winner?.rev ?? newDocObject.rev,
            allLeafRev:
                newDocHistoryObject.leafDocs.map((e) => e.rev).toList());

        // perform actual database operation
        if (winnerBeforeUpdate != null) {
          await db.delete(sequenceTableName,
              key: int.parse(winnerBeforeUpdate.localSeq!), session: session);
          types.add(BatchExecuteType.DELETE);
        }
        await db.batchInsert(sequenceTableName,
            key: newUpdateSeq,
            object: newUpdateSeqObject.toJson(),
            session: session);
        types.add(BatchExecuteType.INSERT);

        await db.put(docTableName,
            key: doc.id,
            object: newDocHistoryObject.toJson(),
            session: session);
        localChangeStreamController.sink.add(newUpdateSeqObject);
        types.add(BatchExecuteType.PUT);

        putResponses
            .add(PutResponse(ok: true, id: doc.id, rev: newDocObject.rev));
      }
    });
    int index = 0;
    for (int i = 0; i < types.length; i++) {
      if (types[i] == BatchExecuteType.PUT && result[i] != null) {
        putResponses[index].ok = true;
        index++;
      }
    }
    return BulkDocResponse(putResponses: putResponses);
  }

  _encodeUpdateSequence(UpdateSequence update,
      {bool? includeDocs = false, String? style = 'main_only'}) async {
    Map<String, dynamic> changeResult = {
      "seq": update.seq,
      "id": update.id,
      "changes": style == 'all_docs'
          ? update.allLeafRev.map((rev) => {"rev": rev.toString()}).toList()
          : [
              {"rev": update.winnerRev.toString()}
            ],
    };

    if (includeDocs == true) {
      DocHistory docs =
          DocHistory.fromJson((await db.get(docTableName, key: update.id))!);

      Map<String, dynamic>? winner = docs.winner
          ?.toDoc<Map<String, dynamic>>(
            update.id,
            (json) => json,
          )
          .toJson((value) => value);

      changeResult["doc"] = winner;
    }
    return jsonEncode(changeResult);
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    StreamController<String> streamController = StreamController();
    var subscription;
    // now get new changes
    String lastSeq =
        (await db.lastSequence(sequenceTableName))?.key.toString() ?? "0";
    if (request.since != 'now') {
      Map<int, dynamic> result = await db.readSequence(sequenceTableName,
          startkey: int.parse(request.since));
      for (MapEntry entry in result.entries) {
        UpdateSequence update = UpdateSequence.fromJson(entry.value);
        streamController.sink.add(await _encodeUpdateSequence(update,
            includeDocs: request.includeDocs, style: request.style));
        lastSeq = update.seq;
        if (request.limit != null) {
          request.limit = request.limit! - 1;
          if (request.limit == 0) {
            streamController.close();
            break;
          }
        }
      }
    }
    if (!streamController.isClosed) {
      if (request.feed == ChangeFeed.continuous) {
        subscription = localChangeStreamController.stream.listen(null);
        subscription.onData((data) async {
          streamController.sink.add(await _encodeUpdateSequence(data,
              includeDocs: request.includeDocs, style: request.style));
        });
      } else if (request.feed == ChangeFeed.longpoll) {
        subscription = localChangeStreamController.stream.listen(null);
        subscription.onData((data) async {
          lastSeq = data.seq;
          streamController.sink.add(await _encodeUpdateSequence(data,
              includeDocs: request.includeDocs, style: request.style));
          subscription.cancel();
          streamController.sink
              .add("\"last_seq\":\"${lastSeq}\", \"pending\": 0}");
          streamController.close();
        });
      } else {
        streamController.sink
            .add("\"last_seq\":\"${lastSeq}\", \"pending\": 0}");
        streamController.close();
      }
    }

    return ChangesStream(
        feed: request.feed,
        stream: streamController.stream,
        onCancel: () async {
          await subscription?.cancel();
          await streamController.close();
        });
  }

  @override
  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      Map<String, dynamic>? partialFilterSelector,
      bool? partitioned}) async {
    if (partialFilterSelector == null) {
      partialFilterSelector = {};
    } else {
      partialFilterSelector =
          PartialFilterSelector().rebuildSelector(partialFilterSelector);
    }
    String timeStamp = DateTime.now().toIso8601String();
    String uniqueName = crypto.md5.convert(utf8.encode(timeStamp)).toString();

    if (name == null) {
      name = uniqueName;
    }
    if (ddoc == null) {
      ddoc = "_design/$uniqueName";
    }
    Doc<DesignDoc>? doc =
        await get(id: ddoc, fromJsonT: (value) => DesignDoc.fromJson(value));

    QueryDesignDocView queryDesignDoc = QueryDesignDocView(
        map: QueryViewMapper(
            partialFilterSelector: partialFilterSelector,
            fields: Map.fromIterable(indexFields,
                key: (item) => item, value: (item) => "asc")),
        reduce: "count",
        options: QueryViewOptions(
            def: QueryViewOptionsDef(
                partialFilterSelector: partialFilterSelector,
                fields: indexFields)));

    if (doc == null) {
      doc = new Doc<DesignDoc>(
          id: ddoc,
          model: DesignDoc(language: "query", views: {name: queryDesignDoc}));
    } else {
      doc.model.views[name] = queryDesignDoc;
    }
    Doc<Map<String, dynamic>> mappedDoc = Doc<Map<String, dynamic>>.fromJson(
        doc.toJson((value) => value.toJson()),
        (json) => json as Map<String, dynamic>);

    PutResponse putResponse = await put(doc: mappedDoc);
    if (putResponse.ok) {
      return IndexResponse(result: "created", id: ddoc, name: name);
    } else {
      throw AdapterException(error: "failed to put design doc");
    }
  }

  @override
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    var history = await db.get(docTableName, key: id);
    DocHistory docHistory = history == null
        ? DocHistory(id: id, docs: {}, revisions: RevisionTree(nodes: []))
        : DocHistory.fromJson(history);
    var winnerBeforeUpdate = docHistory.winner;

    if (winnerBeforeUpdate == null) {
      throw AdapterException(error: 'doc not found');
    }
    var result =
        await put(doc: Doc(id: id, model: {}, deleted: true, rev: rev));

    return DeleteResponse(ok: true, id: id, rev: result.rev);
  }

  Future<DocHistory?> getHistory(String id) async {
    var result = await db.get(docTableName, key: id);
    return result != null ? DocHistory.fromJson(result) : null;
  }

  @override
  Future<bool> destroy() {
    // TODO: implement destroy
    throw UnimplementedError();
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() {
    return Future.value(
        EnsureFullCommitResponse(instanceStartTime: "0", ok: true));
  }

  @override
  Future<Doc<DesignDoc>?> fetchDesignDoc({required String id}) {
    // TODO: implement ensureFullCommit
    throw UnimplementedError();
  }

  Revisions? _getRevisions(
      {required Rev rev, required DocHistory docHistory, required bool revs}) {
    if (revs) {
      return docHistory.getRevision(rev);
    } else
      return null;
  }

  @override
  Future<GetInfoResponse> info() async {
    return Future.value(GetInfoResponse(
        instanceStartTime: "0",
        updateSeq:
            (await db.lastSequence(sequenceTableName))?.key.toString() ?? "0",
        dbName: dbName));
  }

  @override
  Future<bool> init() async {
    throw UnimplementedError();
  }

  _validateUpdate(
      {bool newEdits = true, InternalDoc? winnerBeforeUpdate, Rev? inputRev}) {
    if (newEdits == true) {
      if (winnerBeforeUpdate != null) {
        if (inputRev == null || winnerBeforeUpdate.rev != inputRev) {
          throw AdapterException(
              error: 'update conflict', reason: 'rev is different');
        }
      }
    } else {
      if (inputRev == null) {
        throw AdapterException(
            error: 'missing rev', reason: 'rev is required to update');
      }
    }
  }

  Rev _generateNewRev(
      {required Map<String, dynamic> docToEncode,
      newEdits = true,
      Rev? inputRev,
      InternalDoc? winnerBeforeUpdate,
      Revisions? revisions}) {
    Rev newRev = Rev(index: 0, md5: '0').increase(docToEncode);
    if (newEdits == true) {
      if (winnerBeforeUpdate != null) {
        newRev = winnerBeforeUpdate.rev.increase(docToEncode);
      }
    } else {
      if (revisions != null) {
        newRev = Rev(index: revisions.start, md5: revisions.ids[0]);
      } else {
        newRev = inputRev!;
      }
    }
    return newRev;
  }

  RevisionTree _rebuildRevisionTree(
      {newEdits = true,
      required RevisionTree oldReivisions,
      required Rev newRev,
      InternalDoc? winnerBeforeUpdate,
      Revisions? inputRevision}) {
    Map<String, RevisionNode> mappedRevision = Map.fromIterable(
        oldReivisions.nodes,
        key: (e) => e.rev.toString(),
        value: (e) => e);
    if (newEdits == true) {
      mappedRevision.putIfAbsent(newRev.toString(),
          () => RevisionNode(rev: newRev, prevRev: winnerBeforeUpdate?.rev));
    } else {
      if (inputRevision == null) {
        mappedRevision.putIfAbsent(
            newRev.toString(), () => RevisionNode(rev: newRev));
      } else {
        inputRevision.ids.asMap().forEach((key, value) {
          Rev rev = Rev(index: inputRevision.start - key, md5: value);
          Rev? prevRev;
          if (key < inputRevision.ids.length - 1) {
            prevRev = Rev(
                index: inputRevision.start - key - 1,
                md5: inputRevision.ids[key + 1]);
          }
          mappedRevision.update(rev.toString(), (value) {
            if (value.prevRev == null && prevRev != null) {
              value.prevRev = prevRev;
            }
            return value;
          }, ifAbsent: () => RevisionNode(rev: newRev, prevRev: prevRev));
        });
      }
    }
    return oldReivisions.copyWith(
        nodes: mappedRevision.values.map((e) => e).toList());
  }

  // _generateUpdateSequence({
  //   int? lastKey,
  // }) {
  //   var lastSeq = lastKey ?? '0-1';
  //   return '${int.parse(lastSeq.split('-')[0]) + 1}-1';
  // }

  InternalDoc? _retrieveDocBeforeUpdate({
    newEdits = true,
    required DocHistory docHistory,
    Revisions? revisions,
  }) {
    if (newEdits == true) {
      return docHistory.winner;
    } else {
      if (revisions != null && revisions.ids.length > 1) {
        return docHistory.docs[
            Rev(index: revisions.start - 1, md5: revisions.ids[1]).toString()];
      } else {
        return null;
      }
    }
  }

  @override
  Future<PutResponse> putLocal(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    var history = await db.get(localDocTableName, key: doc.id);
    DocHistory docHistory = history == null
        ? DocHistory(id: doc.id, docs: {}, revisions: RevisionTree(nodes: []))
        : DocHistory.fromJson(history);
    var docJson = doc.toJson((value) => value);
    var winnerBeforeUpdate = docHistory.winner;

    // Validation
    _validateUpdate(
        newEdits: newEdits,
        winnerBeforeUpdate: winnerBeforeUpdate,
        inputRev: doc.rev);

    // get new Rev
    Rev newRev = _generateNewRev(
        docToEncode: docJson,
        newEdits: newEdits,
        winnerBeforeUpdate: winnerBeforeUpdate,
        revisions: doc.revisions,
        inputRev: doc.rev);

    // rebuild rivision tree
    RevisionTree newRevisionTreeObject = _rebuildRevisionTree(
        oldReivisions: docHistory.revisions,
        newRev: newRev,
        winnerBeforeUpdate: winnerBeforeUpdate,
        inputRevision: doc.revisions,
        newEdits: newEdits);

    // create DocHistory Object
    InternalDoc newDocObject = InternalDoc(
        rev: newRev,
        deleted: doc.deleted ?? false,
        data: doc.deleted == true ? {} : doc.model);
    DocHistory newDocHistoryObject = docHistory.copyWith(
        docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
        revisions: newRevisionTreeObject);

    await db.put(docTableName,
        key: doc.id, object: newDocHistoryObject.toJson());

    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    var history = await db.get(docTableName, key: doc.id);
    DocHistory docHistory = history == null
        ? DocHistory(id: doc.id, docs: {}, revisions: RevisionTree(nodes: []))
        : DocHistory.fromJson(history);
    var docJson = doc.toJson((value) => value);
    var winnerBeforeUpdate = docHistory.winner;

    // Validation
    _validateUpdate(
        newEdits: newEdits,
        winnerBeforeUpdate: winnerBeforeUpdate,
        inputRev: doc.rev);

    // get new Rev
    Rev newRev = _generateNewRev(
        docToEncode: docJson,
        newEdits: newEdits,
        winnerBeforeUpdate: winnerBeforeUpdate,
        revisions: doc.revisions,
        inputRev: doc.rev);

    // rebuild rivision tree
    RevisionTree newRevisionTreeObject = _rebuildRevisionTree(
        oldReivisions: docHistory.revisions,
        newRev: newRev,
        winnerBeforeUpdate: winnerBeforeUpdate,
        inputRevision: doc.revisions,
        newEdits: newEdits);

    // create updateSequence object
    var newUpdateSeq =
        ((await db.lastSequence(sequenceTableName))?.key ?? 0) + 1;

    // create DocHistory Object
    InternalDoc newDocObject = InternalDoc(
        rev: newRev,
        deleted: doc.deleted ?? false,
        localSeq: newUpdateSeq.toString(),
        data: doc.deleted == true ? {} : doc.model);
    DocHistory newDocHistoryObject = docHistory.copyWith(
        docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
        revisions: newRevisionTreeObject);

    UpdateSequence newUpdateSeqObject = UpdateSequence(
        id: doc.id,
        seq: newUpdateSeq.toString(),
        winnerRev: newDocHistoryObject.winner?.rev ?? newDocObject.rev,
        allLeafRev: newDocHistoryObject.leafDocs.map((e) => e.rev).toList());

    // perform actual database operation
    await db.runInSession((session) async {
      if (winnerBeforeUpdate != null) {
        await db.delete(sequenceTableName,
            key: int.parse(winnerBeforeUpdate.localSeq!), session: session);
      }
      await db.batchInsert(sequenceTableName,
          key: newUpdateSeq,
          object: newUpdateSeqObject.toJson(),
          session: session);

      await db.put(docTableName,
          key: doc.id, object: newDocHistoryObject.toJson(), session: session);

      localChangeStreamController.sink.add(newUpdateSeqObject);
    });
    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) async {
    Map<String, RevsDiff> revsDiff = {};
    body.forEach((key, value) async {
      var result = await db.get(docTableName, key: key);
      DocHistory docHistory = result != null
          ? DocHistory.fromJson((await db.get(docTableName, key: key))!)
          : new DocHistory(
              id: key, docs: {}, revisions: RevisionTree(nodes: []));
      revsDiff[key] = docHistory.revsDiff(value);
    });
    return revsDiff;
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) {
    // TODO: implement explain
    throw UnimplementedError();
  }

  @override
  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic> p1) toJsonT) {
    // TODO: implement find
    // regenerateView
    // get result from view
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
    var json = await db.get(docTableName, key: id);
    if (json == null) {
      return null;
    }
    var result = DocHistory.fromJson(json);
    return result.winner?.toDoc(id, fromJsonT);
  }

  @override
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
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    //revs, open_revs done

    var json = await db.get(docTableName, key: id);
    if (json == null) {
      return [];
    }
    var docHistory = DocHistory.fromJson(json);
    if (openRevs.all) {
      return docHistory.docs.values
          .map((e) => e.toDoc(id, (json) => fromJsonT(json),
              revisions: _getRevisions(
                  rev: e.rev, docHistory: docHistory, revs: revs)))
          .toList();
    } else {
      List<Doc<T>> list = [];
      openRevs.revs.forEach((rev) {
        if (docHistory.docs.containsKey(rev)) {
          list.add(docHistory.docs[rev]!.toDoc(id, (json) => fromJsonT(json),
              revisions: _getRevisions(
                  rev: Rev.fromString(rev),
                  docHistory: docHistory,
                  revs: revs)));
        }
      });
      return list;
    }
  }

  Future<List<AllDocRow<Map<String, dynamic>>>> view(String ddoc, String viewId,
      {String? startKey,
      String? endKey,
      bool? desc,
      String? startKeyDocId,
      String? endKeyDocId}) async {
    var viewName = _getViewName(designDocId: ddoc, viewId: viewId);
    Doc<DesignDoc>? designDoc =
        await get(id: ddoc, fromJsonT: (value) => DesignDoc.fromJson(value));
    if (designDoc != null) {
      await _generateView(designDoc);

      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      ReadResult result = await db.read(viewKeyTableName(viewName),
          startkey: startKey, endkey: endKey, desc: desc);
      stopwatch.stop();
      print("#6 read ${stopwatch.elapsedMilliseconds}");

      if ((startKey != null && startKeyDocId != null) ||
          (endKey != null && endKeyDocId != null)) {
        result.docs.removeWhere((key, value) =>
            ((startKeyDocId ?? "").compareTo(ViewKey.fromString(key).id) > 0 ||
                (endKeyDocId ?? "\uffff")
                        .compareTo(ViewKey.fromString(key).id) <
                    0));
      }
      List<AllDocRow<Map<String, dynamic>>> rows = [];

      ReadResult readResult = await db.read(docTableName);
      for (var e in result.docs.entries) {
        var key = ViewKey.fromString(e.key);
        DocHistory docs = DocHistory.fromJson(readResult.docs[key.id]);
        // DocHistory docs =
        //     DocHistory.fromJson((await db.get(docTableName, id: key.id))!);

        AllDocRow<Map<String, dynamic>> row = AllDocRow<Map<String, dynamic>>(
            id: key.id,
            key: key.key,
            value: AllDocRowValue.fromJson(e.value['v']),
            doc: docs.winner!
                .toDoc<Map<String, dynamic>>(docs.id, (value) => value));
        rows.add(row);
      }

      return rows;
    } else {
      throw AdapterException(error: "Design Doc Not Exists");
    }
  }

  Future<void> _generateView(Doc<DesignDoc> designDoc) async {
    for (var e in designDoc.model.views.entries) {
      var view = e.value;
      var viewName = _getViewName(designDocId: designDoc.id, viewId: e.key);
      Stopwatch stopwatch1 = new Stopwatch();
      stopwatch1.start();
      var json = await db.get(viewMetaTableName, key: viewName);
      stopwatch1.stop();
      print(
          "#2 db.get(viewMetaTableName, id: viewName) ${stopwatch1.elapsedMilliseconds}");

      ViewMeta meta;
      if (json == null) {
        meta = ViewMeta(lastSeq: '0');
      } else {
        meta = ViewMeta.fromJson(json);
      }
      Stopwatch stopwatch5 = new Stopwatch();
      stopwatch5.start();
      var stream = await changesStream(
          ChangeRequest(since: meta.lastSeq, feed: 'normal'));
      Completer<String> c = new Completer();
      stream.listen(
          onResult: (result) => {},
          onComplete: (resp) async {
            await db.runInSession((session) async {
              for (var result in resp.results) {
                var history = DocHistory.fromJson(
                    (await db.get(docTableName, key: result.id))!);
                Map<String, dynamic>? viewId =
                    await db.get(viewIdTableName(viewName), key: history.id);
                if (viewId != null) {
                  var viewDocMeta = ViewDocMeta.fromJson(viewId);
                  for (var key in viewDocMeta.keys) {
                    await db.delete(viewKeyTableName(viewName),
                        key: key, session: session);
                  }
                  Stopwatch stopwatch2 = new Stopwatch();
                  stopwatch2.start();
                  await db.delete(viewIdTableName(viewName),
                      key: history.id, session: session);
                  stopwatch2.stop();
                  print(
                      "#3 db.delete(viewIdTableName(viewName), id: history.id) ${stopwatch2.elapsedMilliseconds}");
                }

                if (history.winner != null) {
                  var entries = _runMapper(view, history.id, history.winner);
                  if (entries != null) {
                    //change to put in batch
                    for (var entry in entries) {
                      await db.batchInsert(viewKeyTableName(viewName),
                          key: entry.key,
                          object: {"v": entry.value},
                          session: session);
                    }
                    Stopwatch stopwatch3 = new Stopwatch();
                    stopwatch3.start();
                    await db.batchInsert(viewIdTableName(viewName),
                        key: history.id,
                        object: ViewDocMeta(
                                keys: entries.map((e) => e.key).toList())
                            .toJson(),
                        session: session);
                    stopwatch3.stop();
                    print(
                        "#4 db.put(viewIdTableName(viewName) ${stopwatch3.elapsedMilliseconds}");
                  }
                }
              }
            });

            stopwatch5.stop();
            print("#5 changestream ${stopwatch5.elapsedMilliseconds}");
            c.complete(resp.lastSeq);
          });

      var lastSeq = await c.future;
      await db.put(viewMetaTableName,
          key: viewName, object: ViewMeta(lastSeq: lastSeq).toJson());
    }
  }

  List<MapEntry<String, dynamic>>? _runMapper(
      AbstracDesignDocView view, String id, InternalDoc? doc) {
    if (doc != null) {
      if (view is JSDesignDocView) {
        if (jsRuntime == null) {
          throw AdapterException(error: 'no js runtime found');
        }
        jsRuntime?.evaluate(view.map);
      } else if (view is QueryDesignDocView) {
        ///check if partial filter selector !=null
        /// check key got $sign => find its combination_operator
        /// for each key-value stored in combination operators=> conditional-operators-argument, then call conditional operator func
        /// if result = true, output

        String key = '';
        bool isValid = true;

        for (String field in view.map.fields.keys) {
          if (doc.data.containsKey(field)) {
            key = key + "_" + doc.data[field].toString();
          } else if (field == "id") {
            key = key + "_" + id;
          } else {
            isValid = false;
            break;
          }
        }
        if (isValid == true) {
          return [
            MapEntry(ViewKey(id: id, key: key).toString(),
                AllDocRowValue(rev: doc.rev).toJson())
          ];
        } else {
          return null;
        }
      } else if (view is AllDocDesignDocView) {
        return [
          MapEntry(ViewKey(id: id, key: id).toString(),
              AllDocRowValue(rev: doc.rev).toJson())
        ];
      } else {
        throw new UnimplementedError('Unknown Design Doc View');
      }
    }
    return [];
  }

  String _getViewName({required String designDocId, required String viewId}) {
    return '${designDocId}_$viewId';
  }
}
