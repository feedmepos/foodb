import 'dart:async';
import 'dart:convert';

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
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/common/update_sequence.dart';
import 'package:foodb/common/view_meta.dart';

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

abstract class KeyValueDatabase {
  Future<bool> put(String tableName,
      {required String id, required Map<String, dynamic> object});

  Future<bool> delete(String tableName, {required String id});

  Future<Map<String, dynamic>?> get(String tableName, {required String id});

  Future<MapEntry<String, dynamic>?> last(String tableName);

  Future<ReadResult> read(String tableName,
      {String? startKey, String? endKey, bool? desc});

  Future<int> tableSize(String tableName);
}

abstract class JSRuntime {
  evaluate(String script);
}

class KeyValueAdapter extends AbstractAdapter {
  KeyValueDatabase db;
  JSRuntime? jsRuntime;

  KeyValueAdapter({required dbName, required this.db, this.jsRuntime})
      : super(dbName: dbName);

  String get docTableName => '${dbName}_docs';

  String get sequenceTableName => '${dbName}_sequences';

  String get viewMetaTableName => '${dbName}_viewmeta';

  String viewTableName(String viewName) => '${dbName}_view_${viewName}';

  StreamController<UpdateSequence> localChangeStreamController =
      StreamController.broadcast();

  @override
  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var viewName = _getViewName(designDocId: '_all_docs', viewId: '_all_docs');

    await _generateView(Doc<DesignDoc>(
        id: '_all_docs',
        model: DesignDoc(views: {'_all_docs': AllDocDesignDocView()})));

    ReadResult result = await _findByView(viewName,
        startKey: allDocsRequest.startKeyDocId,
        endKey: allDocsRequest.endKeyDocId,
        desc: allDocsRequest.descending);

    return GetAllDocs(
        offset: result.offset,
        totalRows: result.totalRows,
        rows: result.docs.values
            .map<Row<T>>((e) => Row<T>(
                id: e["_id"],
                key: e["_id"],
                value: Value(rev: e["_rev"]),
                doc: Doc<T>.fromJson(
                    e, (json) => fromJsonT(json as Map<String, dynamic>))))
            .toList());
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = false}) async {
    List<PutResponse> putResponses = [];
    for (var doc in body) {
      putResponses.add(await put(doc: doc, newEdits: newEdits));
    }
    return BulkDocResponse(putResponses: putResponses);
  }

  _encodeUpdateSequence(UpdateSequence update,
      {bool? includeDocs = false, String? style = 'main_only'}) async {
    Map<String, dynamic> changeResult = {
      "seq": update.seq,
      "id": update.id,
      "changes": style == 'all'
          ? update.allLeafRev.map((rev) => {"rev": rev}).toList()
          : [
              {"rev": update.winnerRev}
            ],
    };

    if (includeDocs == true) {
      DocHistory docs =
          DocHistory.fromJson((await db.get(docTableName, id: update.id))!);

      Map<String, dynamic> winner = docs.winner!.toJson();
      winner.removeWhere((key, value) => value == null);
      changeResult["doc"] = winner;
    }
    return jsonEncode(changeResult);
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    StreamController<String> streamController = StreamController();
    var subscription;
    // now get new changes
    String lastSeq = (await db.read(sequenceTableName)).docs.keys.last;
    if (request.since != 'now') {
      ReadResult result =
          await db.read(sequenceTableName, startKey: request.since);
      for (MapEntry entry in result.docs.entries) {
        UpdateSequence update = UpdateSequence.fromJson(entry.value);
        streamController.sink.add(await _encodeUpdateSequence(update,
            includeDocs: request.includeDocs, style: request.style));

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
          await subscription.cancel();
          await streamController.close();
        });
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
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    var history = await db.get(docTableName, id: id);
    DocHistory docHistory = history == null
        ? DocHistory(id: id, docs: {}, revisions: RevisionTree(nodes: []))
        : DocHistory.fromJson(history);
    var winnerBeforeUpdate = docHistory.winner;

    if (winnerBeforeUpdate == null) {
      throw AdapterException(error: 'doc not found');
    }

    var result = await put(
        doc:
            Doc(id: id, model: {}, deleted: true, rev: winnerBeforeUpdate.rev));

    return DeleteResponse(ok: true, id: id, rev: result.rev);
  }

  Future<DocHistory?> getHistory(String id) async {
    var result = await db.get(docTableName, id: id);
    return result != null ? DocHistory.fromJson(result) : null;
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
  Future<Doc<DesignDoc>?> fetchDesignDoc({required String id}) {
    // TODO: implement ensureFullCommit
    throw UnimplementedError();
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
      required Object openRevs,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) {
    // TODO: implement getWithOpenRev
    throw UnimplementedError();
  }

  @override
  Future<GetInfoResponse> info() {
    // TODO: implement info
    throw UnimplementedError();
  }

  @override
  Future<bool> init() async {
    throw UnimplementedError();
  }

  _validateUpdate(
      {newEdits = true, InternalDoc? winnerBeforeUpdate, Rev? inputRev}) {
    if (newEdits == true) {
      if (winnerBeforeUpdate != null) {
        if (inputRev == null || winnerBeforeUpdate.rev == inputRev) {
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
          if (key < inputRevision.ids.length) {
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

  _generateUpdateSequence({
    String? lastKey,
  }) {
    var lastSeq = lastKey ?? '0-1';
    return '${int.parse(lastSeq.split('-')[0]) + 1}-1';
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    var history = await db.get(docTableName, id: doc.id);
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
        docToEncode: doc.toJson((value) => value),
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
    var newUpdateSeq = _generateUpdateSequence(
        lastKey: (await db.last(sequenceTableName))?.key);

    // create DocHistory Object
    InternalDoc newDocObject = InternalDoc(
        rev: newRev,
        deleted: doc.deleted ?? false,
        localSeq: newUpdateSeq,
        data: doc.model);
    DocHistory newDocHistoryObject = docHistory.copyWith(
        docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
        revisions: newRevisionTreeObject);
    UpdateSequence newUpdateSeqObject = UpdateSequence(
        id: doc.id,
        seq: newUpdateSeq,
        winnerRev: newDocHistoryObject.winner!.rev,
        allLeafRev: newDocHistoryObject.leafDocs.map((e) => e.rev).toList());

    // perform actual database operation
    if (winnerBeforeUpdate != null) {
      await db.delete(sequenceTableName, id: winnerBeforeUpdate.localSeq);
    }
    await db.put(sequenceTableName,
        id: newUpdateSeqObject.seq, object: newUpdateSeqObject.toJson());
    await db.put(docTableName,
        id: doc.id, object: newDocHistoryObject.toJson());

    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) async {
    Map<String, RevsDiff> revsDiff = {};
    body.forEach((key, value) async {
      DocHistory docHistory =
          DocHistory.fromJson((await db.get(docTableName, id: key))!);
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
    var json = await db.get(docTableName, id: id);
    if (json == null) {
      return null;
    }
    var result = DocHistory.fromJson(json);
    if (result.winner?.deleted == true) {
      return null;
    }
    return result.winner!.toDoc(id, fromJsonT);
  }

  Future<void> _generateView(Doc<DesignDoc> designDoc) async {
    for (var e in designDoc.model.views.entries) {
      var view = e.value;
      var viewName = _getViewName(designDocId: designDoc.id, viewId: e.key);
      var json = await db.get(viewMetaTableName, id: viewName);
      ViewMeta meta;
      if (json == null) {
        meta = ViewMeta(lastSeq: '0');
      } else {
        meta = ViewMeta.fromJson(json);
      }
      var stream = await changesStream(
          ChangeRequest(since: meta.lastSeq, feed: 'normal'));
      Completer<String> c = new Completer();
      stream.listen(
          onResult: (result) => print(result),
          onComplete: (resp) async {
            for (var result in resp.results) {
              var history = DocHistory.fromJson(
                  (await db.get(docTableName, id: result.id))!);
              var entries = _runMapper(view, history);
              for (var entry in entries) {
                await db.put(viewTableName(viewName),
                    id: entry.key, object: entry.value);
              }
            }
            c.complete(resp.lastSeq);
          });

      var lastSeq = await c.future;
      await db.put(viewMetaTableName,
          id: viewName, object: ViewMeta(lastSeq: lastSeq).toJson());
    }
  }

  List<MapEntry<String, dynamic>> _runMapper(
      AbstracDesignDocView view, DocHistory history) {
    if (view is JSDesignDocView) {
      if (jsRuntime == null) {
        throw AdapterException(error: 'no js runtime found');
      }
      jsRuntime?.evaluate(view.map);
      // TODO use runtime to run mapper
    } else if (view is QueryDesignDocView) {
      // TODO create dart mapper using query field
    } else if (view is AllDocDesignDocView) {
      return history.winner?.deleted != true
          ? [MapEntry(history.id, history.winner?.data)]
          : [];
    } else {
      throw new UnimplementedError('Unknown Design Doc View');
    }
    return [];
  }

  Future<ReadResult> _findByView(String viewName,
      {String? startKey, String? endKey, required bool desc}) async {
    return await db.read(viewTableName(viewName),
        startKey: startKey, endKey: endKey, desc: desc);
  }

  String _getViewName({required String designDocId, required String viewId}) {
    return '${designDocId}_$viewId';
  }
}
