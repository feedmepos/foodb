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
import 'package:foodb/adapter/utils.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/view_meta.dart';

abstract class KeyValueDatabase {
  Future<bool> put(String tableName,
      {required String id, required Map<String, dynamic> object});
  Future<bool> delete(String tableName, {required String id});
  Future<Map<String, dynamic>?> get(String tableName, {required String id});
  Future<Map<String, Map<String, dynamic>>> read(String tableName,
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

  List<StreamController<String>> _continuousStreamControllers = [];
  List<StreamController<String>> _longPollStreamControllers = [];
  List<ChangeRequest> _continuousChangeRequests = [];
  List<ChangeRequest> _longPollChangeRequests = [];

  void addChanges(
      {required String seq,
      required String id,
      required DocHistory history}) async {
    print(_longPollStreamControllers.length);
    Map<String, dynamic> changeResult = {
      "seq": seq,
      "id": id,
      "changes": history.leafDocs.map((e) => {"rev": e.rev}).toList()
    };
    Map<String, dynamic> changeResultWithDoc = changeResult;
    Map<String, dynamic> winner = history.winner!.toJson((value) => value);
    winner.removeWhere((key, value) => value == null);
    changeResultWithDoc["doc"] = winner;

    for (int x = 0; x < _continuousStreamControllers.length; x++) {
      _continuousStreamControllers[x].sink.add(jsonEncode(
          _continuousChangeRequests[x].includeDocs == true
              ? changeResultWithDoc
              : changeResult));
      if (_continuousChangeRequests[x].limit != null) {
        _continuousChangeRequests[x].limit =
            _continuousChangeRequests[x].limit! - 1;
        if (_continuousChangeRequests[x].limit == 0) {
          _continuousStreamControllers[x].close();
          _continuousStreamControllers.removeAt(x);
          _continuousChangeRequests.removeAt(x);
        }
      }
    }

    for (int x = 0; x < _longPollStreamControllers.length; x++) {
      _longPollStreamControllers[x].sink.add(jsonEncode(
          _longPollChangeRequests[x].includeDocs == true
              ? changeResultWithDoc
              : changeResult));
      _longPollStreamControllers[x]
          .sink
          .add("\"last_seq\":\"$seq\", \"pending\": 0}");
      _longPollStreamControllers[x].close();
      _longPollStreamControllers.removeAt(x);
      _longPollChangeRequests.removeAt(x);
    }
  }

  @override
  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var viewName = _getViewName(designDocId: '_all_docs', viewId: '_all_docs');

    await _generateView(Doc<DesignDoc>(
        id: '_all_docs',
        model: DesignDoc(views: {'_all_docs': AllDocDesignDocView()})));

    Map<String, Map<String, dynamic>> map = await _findByView(viewName,
        startKey: allDocsRequest.startKey,
        endKey: allDocsRequest.endKey,
        desc: allDocsRequest.descending);

    return GetAllDocs(
        offset: 0,
        totalRows: await db.tableSize(viewTableName(viewName)),
        rows: map.values
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
    throw UnimplementedError();
  }

  Future<void> iniChangesStream(
      StreamController<String> streamController, ChangeRequest request) async {
    String lastSeq = '';
    if (request.since != 'now') {
      Map<String, dynamic> result =
          await db.read(sequenceTableName, startKey: request.since);
      for (MapEntry entry in result.entries) {
        lastSeq = entry.key;

        DocHistory<Map<String, dynamic>> docs =
            DocHistory<Map<String, dynamic>>.fromJson(
                (await db.get(docTableName, id: entry.value['id']))!,
                (json) => json as Map<String, dynamic>);

        Map<String, dynamic> changeResult = {
          "seq": entry.key,
          "id": entry.value["id"],
          "changes": docs.leafDocs.map((e) => {"rev": e.rev}).toList()
        };
        if (request.includeDocs) {
          Map<String, dynamic> winner = docs.winner!.toJson((value) => value);
          winner.removeWhere((key, value) => value == null);
          changeResult["doc"] = winner;
        }
        streamController.onListen = () {
          streamController.sink.add(jsonEncode(changeResult));
        };

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
        _continuousStreamControllers.add(streamController);
        _continuousChangeRequests.add(request);
      } else if (request.feed == ChangeFeed.longpoll) {
        _longPollStreamControllers.add(streamController);
        _longPollChangeRequests.add(request);
      } else {
        if (request.since == 'now') {
          //if dont want put future.delayed, what should I put at here???
          //await Future.delayed(Duration(seconds: 1)).then((value) async =>
          lastSeq = (await db.read(sequenceTableName)).keys.last;
          //);
        }

        streamController.onListen = () {
          streamController.sink
              .add("\"last_seq\":\"${lastSeq}\", \"pending\": 0}");
        };
        // streamController.sink
        //     .add("\"last_seq\":\"${lastSeq}\", \"pending\": 0}");
        streamController.close();
      }
    }
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    StreamController<String> streamController =
        new StreamController<String>.broadcast();

    await iniChangesStream(streamController, request);
    // streamController.onListen = () {
    //   streamController.sink.add("\"last_seq\":\"0\", \"pending\": 0}");
    // };
    return ChangesStream(
        feed: request.feed,
        stream: streamController.stream,
        cancel: () {
          if (request.feed == ChangeFeed.longpoll) {
            int index = _longPollStreamControllers.indexOf(streamController);
            _longPollChangeRequests.remove(index);
            _longPollStreamControllers.remove(streamController);
          } else if (request.feed == ChangeFeed.normal) {
            int index = _continuousStreamControllers.indexOf(streamController);
            _continuousChangeRequests.remove(index);
            _continuousStreamControllers.remove(streamController);
          }
          streamController.close();
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
  Future<DeleteResponse> delete(
      {required String id, required String rev}) async {
    var result = await db.get(docTableName, id: id);
    if (result != null) {
      var history = DocHistory.fromJson(result, (json) => json);
      if (history.winner?.rev != rev) {
        throw AdapterException(error: 'Invalid rev');
      } else {
        // TODO create a new rev as delete;
      }
      return DeleteResponse(ok: true);
    } else {
      return DeleteResponse(ok: false);
    }
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

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc,
      bool newEdits = true,
      String? newRev}) async {
    var result = await db.get(docTableName, id: doc.id);
    var rev = newEdits ? doc.rev ?? RevisionTool.generate() : newRev;
    var newDoc = doc.toJson((value) => value);
    // first revision
    if (result == null) {
      newDoc['_rev'] = newEdits ? RevisionTool.generate() : newRev;
      db.put(docTableName, id: doc.id, object: newDoc);
    } else {
      var docList = result as List<dynamic>;
      var highestRev = -1;
      var highestRevIndex = 0;
      docList.asMap().forEach((key, value) {
        var rev = RevisionTool(value['_rev']).index;
        if (rev > highestRev) highestRevIndex = key;
      });
      var resultObject = Doc.fromJson(docList[highestRevIndex], (json) => json);
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
        db.put(docTableName, id: doc.id, object: newDoc);
      } else {
        newDoc['_rev'] = RevisionTool(resultObject.rev!).increment();
        db.put(docTableName, id: doc.id, object: newDoc);
      }
    }
    _updateSequence(id: doc.id, rev: rev!);
    return PutResponse(ok: true);
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
    var result = DocHistory<T>.fromJson(
        json, (e) => fromJsonT(e as Map<String, dynamic>));
    if (result.winner?.deleted == true) {
      return null;
    }
    return result.winner;
  }

  Future<void> _postUpdate() async {
    // decide winner
    // update sequence
  }

  Future<void> _updateSequence(
      {required String id, required String rev}) async {
    int lastSeq = await db.tableSize(sequenceTableName);
    String newSeqString = Utils.generateSequence(lastSeq + 1);
    await db.put(sequenceTableName,
        id: newSeqString,
        object: ChangeResult(
            id: id,
            seq: newSeqString,
            changes: [ChangeResultRev(rev: rev)]).toJson());
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
      stream.onResult((result) => print(result));
      stream.onComplete((resp) async {
        print(resp.toJson());
        for (var result in resp.results) {
          var history = DocHistory<Map<String, dynamic>>.fromJson(
              (await db.get(docTableName, id: result.id))!,
              (json) => json as Map<String, dynamic>);
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
      AbstracDesignDocView view, DocHistory<Map<String, dynamic>> history) {
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
          ? [MapEntry(history.winner!.id, history.winner?.model)]
          : [];
    } else {
      throw new UnimplementedError('Unknown Design Doc View');
    }
    return [];
  }

  _findByView(String viewName,
      {String? startKey, String? endKey, required bool desc}) {
    return db.read(viewTableName(viewName),
        startKey: startKey, endKey: endKey, desc: desc);
  }

  _getViewName({required String designDocId, required String viewId}) {
    return '${designDocId}_${viewId}';
  }
}
