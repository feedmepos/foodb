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

abstract class AbstractDataType {
  String type;
  AbstractDataType({
    required this.type,
  });
}

class DocDataType extends AbstractDataType {
  DocDataType({String type = "doc"}) : super(type: type);
}

class LocalDocDataType extends AbstractDataType {
  LocalDocDataType({String type = "local_doc"}) : super(type: type);
}

class SequenceDataType extends AbstractDataType {
  SequenceDataType({String type = "sequence"}) : super(type: type);
}

class ViewMetaDataType extends AbstractDataType {
  ViewMetaDataType({String type = "view_meta"}) : super(type: type);
}

class ViewIdDataType extends AbstractDataType {
  ViewIdDataType({String type = "view_id"}) : super(type: type);
}

class ViewKeyDataType extends AbstractDataType {
  ViewKeyDataType({String type = "view_key"}) : super(type: type);
}

abstract class KeyValueDatabase {
  @protected
  Future<bool> put(AbstractDataType type,
      {required String key, required Map<String, dynamic> object});

  @protected
  Future<bool> putMany(AbstractDataType type,
      {required Map<String, dynamic> objects});

  @protected
  Future<bool> delete(AbstractDataType type, {required String key});

  @protected
  Future<bool> deleteMany(AbstractDataType type, {required List<String> keys});

  @protected
  Future<bool> deleteTable(AbstractDataType type);

  @protected
  Future<bool> deleteDatabase();

  @protected
  Future<Map<String, dynamic>?> get(AbstractDataType type,
      {required String key});

  @protected
  Future<Map<String, dynamic>> getMany(AbstractDataType type,
      {required List<String> keys});

  @protected
  Future<MapEntry<String, dynamic>?> last(AbstractDataType type);

  @protected
  Future<ReadResult> read(AbstractDataType type,
      {String? startkey, String? endkey, bool? desc});

  @protected
  Future<int> tableSize(AbstractDataType type);

  @protected
  Future<void> insert(AbstractDataType type,
      {required String key, required Map<String, dynamic> object});

  @protected
  Future<void> insertMany(AbstractDataType type,
      {required Map<String, dynamic> objects});

  @protected
  Future<void> update(
    AbstractDataType type, {
    required String key,
    required Map<String, dynamic> object,
  });
}

abstract class JSRuntime {
  evaluate(String script);
}

class KeyValueAdapter extends AbstractAdapter {
  KeyValueDatabase db;
  JSRuntime? jsRuntime;

  KeyValueAdapter({required dbName, required this.db, this.jsRuntime})
      : super(dbName: dbName);

  StreamController<UpdateSequence> localChangeStreamController =
      StreamController.broadcast();

  @override
  Future<GetAllDocsResponse<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var viewName = _getViewName(designDocId: '_all_docs', viewId: '_all_docs');

    await _generateView(Doc<DesignDoc>(
        id: '_all_docs',
        model: DesignDoc(views: {'_all_docs': AllDocDesignDocView()})));

    ReadResult result = await db.read(ViewKeyDataType(type: viewName),
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
    Map<String, dynamic>? mappedDocs;
    if (allDocsRequest.includeDocs) {
      mappedDocs = await db.getMany(DocDataType(),
          keys: result.docs.keys.map((e) => ViewKey.fromString(e).id).toList());
    }
    for (var e in filteredResult) {
      var key = ViewKey.fromString(e.key);
      AllDocRow<T> row = AllDocRow<T>(
        id: key.id,
        key: key.key,
        value: AllDocRowValue.fromJson(e.value['v']),
      );
      if (allDocsRequest.includeDocs) {
        DocHistory docs = DocHistory.fromJson(mappedDocs![key.id]);
        row.doc = docs.winner!.toDoc<T>(docs.id, fromJsonT);
      }
      rows.add(row);
    }

    return GetAllDocsResponse<T>(
        offset: result.offset, totalRows: result.totalRows, rows: rows);
  }

  @override
  Future<Map<String, List<Doc<T>>>> bulkGet<T>(
      {required List<Map<String, dynamic>> body,
      bool revs = false,
      bool latest = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) {
    throw UnimplementedError();
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = false}) async {
    List<PutResponse> putResponses = [];

    int newUpdateSeq =
        int.parse((await db.last(SequenceDataType()))?.key ?? "0");

    List<String> deletedSequences = [];
    Map<String, dynamic> insertedSequences = {};

    await Future.forEach(body, (Doc<Map<String, dynamic>> doc) async {
      var history = await db.get(DocDataType(), key: doc.id);
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

      newUpdateSeq = newUpdateSeq + 1;

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
      if (winnerBeforeUpdate != null) {
        // deletedSequences.add(winnerBeforeUpdate.localSeq!);
        await db.delete(SequenceDataType(), key: winnerBeforeUpdate.localSeq!);
      }
      //insertedSequences[newUpdateSeq.toString()] = newUpdateSeqObject.toJson();
      await db.insert(SequenceDataType(), key: newUpdateSeq.toString(), object:  newUpdateSeqObject.toJson());

      bool ok = await db.put(
        DocDataType(),
        key: doc.id,
        object: newDocHistoryObject.toJson(),
      );

      localChangeStreamController.sink.add(newUpdateSeqObject);

      putResponses.add(PutResponse(ok: ok, id: doc.id, rev: newDocObject.rev));
    });
    //await db.deleteMany(SequenceDataType(), keys: deletedSequences);
   // await db.insertMany(SequenceDataType(), objects: insertedSequences);

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
          DocHistory.fromJson((await db.get(DocDataType(), key: update.id))!);

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
    String lastSeq = (await db.last(SequenceDataType()))?.key ?? "0";
    if (request.since != 'now') {
      ReadResult result =
          await db.read(SequenceDataType(), startkey: request.since);
      Iterable<MapEntry<String, dynamic>> entries = result.docs.entries;
      for (MapEntry entry in entries) {
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

  //alldocs need index doc oso
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
          PartialFilterSelector().generateSelector(partialFilterSelector);
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
    var history = await db.get(DocDataType(), key: id);
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
    var result = await db.get(DocDataType(), key: id);
    return result != null ? DocHistory.fromJson(result) : null;
  }

  @override
  Future<bool> destroy() async {
    return await db.deleteDatabase();
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
        updateSeq: (await db.last(SequenceDataType()))?.key.toString() ?? "0",
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

  @override
  Future<PutResponse> putLocal(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    var history = await db.get(LocalDocDataType(), key: doc.id);
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

    await db.put(DocDataType(),
        key: doc.id, object: newDocHistoryObject.toJson());

    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    var history = await db.get(DocDataType(), key: doc.id);
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
        int.parse((await db.last(SequenceDataType()))?.key ?? "0") + 1;

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
    if (winnerBeforeUpdate != null) {
      await db.delete(
        SequenceDataType(),
        key: winnerBeforeUpdate.localSeq!,
      );
    }
    await db.insert(
      SequenceDataType(),
      key: newUpdateSeq.toString(),
      object: newUpdateSeqObject.toJson(),
    );

    await db.put(
      DocDataType(),
      key: doc.id,
      object: newDocHistoryObject.toJson(),
    );

    localChangeStreamController.sink.add(newUpdateSeqObject);
    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) async {
    Map<String, RevsDiff> revsDiff = {};
    await Future.forEach(body.keys, (String key) async {
      var result = await db.get(DocDataType(), key: key);
      DocHistory docHistory = result != null
          ? DocHistory.fromJson((await db.get(DocDataType(), key: key))!)
          : new DocHistory(
              id: key, docs: {}, revisions: RevisionTree(nodes: []));
      revsDiff[key] = docHistory.revsDiff(body[key]!);
    });
    return revsDiff;
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    PartialFilterSelector generator = new PartialFilterSelector();
    Map<String, dynamic> newSelector =
        generator.generateSelector(findRequest.selector);
    if (findRequest.sort != null) {
      ViewKey? viewKey = await _findSelectorIndexByFields(findRequest.sort!);
      if (viewKey != null) {
      } else {}
    }

    throw UnimplementedError();
  }

  //Position Order Considered
  Future<ViewKey?> _findSelectorIndexByFields(
      List<Map<String, String>> sort) async {
    ReadResult readResult = await db.read(DocDataType(),
        startkey: "_design", endkey: "_design\uffff");
    List<String> keys = sort.map<String>((e) => e.keys.toList()[0]).toList();

    Map<ViewKey, int> matchedPositions = {};
    List<Doc<DesignDoc>> docs = readResult.docs.values
        .map((e) => Doc.fromJson(
            e, (json) => DesignDoc.fromJson(json as Map<String, dynamic>)))
        .toList();
    docs.forEach((doc) {
      doc.model.views.forEach((key, value) {
        ViewKey viewKey = ViewKey(id: doc.id, key: key);
        if (value is QueryDesignDocView) {
          if (keys.length == value.options.def.fields.length) {
            matchedPositions[viewKey] = 0;
            for (int x = 0; x < keys.length; x++) {
              if (keys[x] == value.options.def.fields[x]) {
                matchedPositions[viewKey] = matchedPositions[viewKey]! + 1;
              } else {
                matchedPositions.remove(viewKey);
              }
            }
          }
        }
      });
    });

    List<ViewKey>? matchedViewKey = matchedPositions.entries
        .where((element) => element.value == keys.length)
        .map((e) => e.key)
        .toList();

    if (matchedViewKey.length > 0) {
      return matchedViewKey[0];
    }
    return null;
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
    var json = await db.get(DocDataType(), key: id);
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

    var json = await db.get(DocDataType(), key: id);
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

      ReadResult result = await db.read(ViewKeyDataType(type: viewName),
          startkey: startKey, endkey: endKey, desc: desc);

      if ((startKey != null && startKeyDocId != null) ||
          (endKey != null && endKeyDocId != null)) {
        result.docs.removeWhere((key, value) =>
            ((startKeyDocId ?? "").compareTo(ViewKey.fromString(key).id) > 0 ||
                (endKeyDocId ?? "\uffff")
                        .compareTo(ViewKey.fromString(key).id) <
                    0));
      }
      List<AllDocRow<Map<String, dynamic>>> rows = [];

      Map<String, dynamic> map = await db.getMany(DocDataType(),
          keys: result.docs.entries
              .map<String>((e) => ViewKey.fromString(e.key).id)
              .toList());
      for (var e in result.docs.entries) {
        ViewKey key = ViewKey.fromString(e.key);
        DocHistory docs = DocHistory.fromJson(map[key.id]);
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
      var json = await db.get(ViewMetaDataType(), key: viewName);

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
          onResult: (result) => {},
          onComplete: (resp) async {
            List<String> keys = resp.results.map((e) => e.id).toList();
            Map<String, dynamic> mapResults =
                await db.getMany(DocDataType(), keys: keys);
            for (var id in keys) {
              var history = DocHistory.fromJson(mapResults[id]);
              Map<String, dynamic>? viewId =
                  await db.get(ViewIdDataType(type: viewName), key: history.id);
              if (viewId != null) {
                List<String> keysForDelete = [];

                var viewDocMeta = ViewDocMeta.fromJson(viewId);
                for (var key in viewDocMeta.keys) {
                  keysForDelete.add(key);
                }
                await db.delete(
                  ViewIdDataType(type: viewName),
                  key: history.id,
                );
                await db.deleteMany(ViewKeyDataType(type: viewName),
                    keys: keysForDelete);
              }

              if (history.winner != null) {
                var entries = _runMapper(view, history.id, history.winner);
                if (entries != null) {
                  //change to put in batch
                  Map<String, dynamic> mapForInsert = {};
                  for (var entry in entries) {
                    mapForInsert[entry.key] = {"v": entry.value};
                  }
                  await db.insert(
                    ViewIdDataType(type: viewName),
                    key: history.id,
                    object:
                        ViewDocMeta(keys: entries.map((e) => e.key).toList())
                            .toJson(),
                  );

                  await db.insertMany(
                    ViewKeyDataType(type: viewName),
                    objects: mapForInsert,
                  );
                }
              }
            }

            c.complete(resp.lastSeq);
          });

      var lastSeq = await c.future;
      await db.put(ViewMetaDataType(),
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
