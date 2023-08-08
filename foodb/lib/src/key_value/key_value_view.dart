part of '../../foodb.dart';

Map<ViewKeyMeta, ViewValueDoc> _runMapper(
    AbstracDesignDocView view, String id, InternalDoc? doc) {
  Map<ViewKeyMeta, ViewValueDoc> resultMap = Map();
  if (doc != null) {
    if (view is JSDesignDocView) {
      throw UnimplementedError();
    } else if (view is QueryDesignDocView) {
      final keysToIndex = view.map.fields.keys;
      final objectKeys = doc.data.keys
          .where((element) => keysToIndex.contains(element))
          .toList();

      // object missing key, do not index;
      if (objectKeys.length < keysToIndex.length) {
        return resultMap;
      }

      resultMap.putIfAbsent(
          ViewKeyMeta(
              key: keysToIndex
                  .map((e) => e == "_id" ? id : doc.data[e])
                  .toList()),
          () => ViewValueDoc(docId: id));
      return resultMap;
    } else if (view is AllDocDesignDocView) {
      resultMap.putIfAbsent(ViewKeyMeta(key: id),
          () => ViewValueDoc(docId: id, value: {"rev": doc.rev.toString()}));
    } else {
      throw new UnimplementedError('Unknown Design Doc View');
    }
  }
  return resultMap;
}

class _GenerateViewReq {
  AbstracDesignDocView view;
  String viewName;
  Map<DocKey, Map<String, dynamic>?> docs;
  Map<ViewDocMetaKey, Map<String, dynamic>?> docMetas;
  _GenerateViewReq({
    required this.view,
    required this.viewName,
    required this.docs,
    required this.docMetas,
  });
}

class _GenerateViewRes {
  Map<ViewDocMetaKey, Map<String, dynamic>> docMetas;
  Map<ViewKeyMetaKey, ViewValue> keyToAdd;
  Map<ViewKeyMetaKey, ViewValue> keyToRemove;
  _GenerateViewRes({
    required this.docMetas,
    required this.keyToAdd,
    required this.keyToRemove,
  });
}

/**
 * For each doc,
 * remove previous key and reset doc meta
 * run mapper to generate new key
 * add new key and update doc meta
 */
Future<_GenerateViewRes> generateViewForDocs(_GenerateViewReq req) async {
  final view = req.view;
  final docMetas = req.docMetas.map((key, value) => MapEntry(key,
      value != null ? ViewDocMeta.fromJson(value) : ViewDocMeta(keys: [])));
  final viewName = req.viewName;
  final keyToAdd = Map<ViewKeyMetaKey, ViewValue>();
  final keyToRemove = Map<ViewKeyMetaKey, ViewValue>();
  final docsToProcess = req.docs.map((key, value) =>
      MapEntry(key, value != null ? DocHistory.fromJson(value) : null));

  for (var doc in docsToProcess.values) {
    if (doc == null) continue;
    var docMetaKey = ViewDocMetaKey(viewName: viewName, key: doc.id);
    final existDocMeta = docMetas[docMetaKey];
    if (existDocMeta != null) {
      List<ViewKeyMeta> keysForDelete = existDocMeta.keys;
      for (final k in keysForDelete) {
        var key = ViewKeyMetaKey(key: k, viewName: viewName);
        keyToRemove.update(key, (value) {
          value.docs.add(ViewValueDoc(docId: doc.id));
          return value;
        }, ifAbsent: () {
          return ViewValue(docs: [ViewValueDoc(docId: doc.id)]);
        });
      }
      existDocMeta.keys = [];
    }
    if (doc.winner != null) {
      var entries = _runMapper(view, doc.id, doc.winner);
      for (final e in entries.entries) {
        var key = ViewKeyMetaKey(viewName: viewName, key: e.key);
        keyToAdd.update(key, (value) {
          value.docs.add(e.value);
          return value;
        }, ifAbsent: () {
          return ViewValue(docs: [e.value]);
        });
      }
      docMetas.update(docMetaKey, (value) {
        value.keys = entries.keys.toList();
        return value;
      }, ifAbsent: () {
        return ViewDocMeta(keys: entries.keys.toList());
      });
    }
  }
  return _GenerateViewRes(
      docMetas: docMetas.map((key, value) => MapEntry(key, value.toJson())),
      keyToAdd: keyToAdd,
      keyToRemove: keyToRemove);
}

mixin _KeyValueView on _AbstractKeyValue {
  Map<String, Lock> _locks = {};

  Lock _getLock(String viewName) {
    if (!_locks.containsKey(viewName)) {
      _locks[viewName] = Lock();
    }
    return _locks[viewName]!;
  }

  Future<void> _generateView(Doc<DesignDoc> designDoc) async {
    for (var e in designDoc.model.views.entries) {
      var view = e.value;
      var viewName =
          keyValueDb.getViewTableName(designDocId: designDoc.id, viewId: e.key);
      var json = (await keyValueDb.get(ViewMetaKey(key: viewName)))?.value;

      ViewMeta meta;
      if (json == null) {
        meta = ViewMeta(lastSeq: 0);
      } else {
        meta = ViewMeta.fromJson(json);
      }
      var c = new Completer();
      int pending = 1;
      processChange(String since) async {
        await _getLock(viewName).synchronized(() async {
          FoodbDebug.timedStart('<_generateView>: getChange');
          var getChange = new Completer<ChangeResponse>();
          changesStream(
              ChangeRequest(limit: 300, since: since, feed: ChangeFeed.normal),
              onComplete: getChange.complete);
          var resp = await getChange.future;
          pending = resp.pending ?? 0;
          FoodbDebug.timedEnd('<_generateView>: getChange');

          List<String> docIdToProcess = resp.results.map((e) => e.id).toList();

          FoodbDebug.timedStart('<_generateView>: getDocToProcess');
          final docsToProcess = (await keyValueDb.getMany<DocKey>(
              docIdToProcess.map<DocKey>((k) => DocKey(key: k)).toList()));
          FoodbDebug.timedEnd('<_generateView>: getDocToProcess');
          FoodbDebug.timedStart('<_generateView>: getDocMetas');
          final docMetas = (await keyValueDb.getMany<ViewDocMetaKey>(
              docIdToProcess
                  .map((e) => ViewDocMetaKey(viewName: viewName, key: e))
                  .toList()));
          FoodbDebug.timedEnd('<_generateView>: getDocMetas');
          FoodbDebug.timedStart('<_generateView>: generateView');
          var res = await generateViewForDocs(_GenerateViewReq(
              view: view,
              viewName: viewName,
              docs: docsToProcess,
              docMetas: docMetas));
          // var res = await FoodbWorker.execute(
          //     generateViewForDocs,
          //     _GenerateViewReq(
          //         view: view,
          //         viewName: viewName,
          //         docs: docsToProcess,
          //         docMetas: docMetas));
          FoodbDebug.timedEnd('<_generateView>: generateView');

          final newDocMetas = res.docMetas;
          final keyToAdd = res.keyToAdd;
          final keyToRemove = res.keyToRemove;

          var fullKeyToChange = [
            ...keyToRemove.keys.toList(),
            ...keyToAdd.keys.toList()
          ];
          FoodbDebug.timedStart('<_generateView>: updateKey');
          var fullKey = (await keyValueDb.getMany(fullKeyToChange)).map(
              (key, value) => MapEntry(
                  key,
                  value != null
                      ? ViewValue.fromJson(value)
                      : ViewValue(docs: [])));
          keyToRemove.forEach((key, value) {
            var exist = fullKey[key]!;
            exist.docs.removeWhere((element) => value.docs.any((e2) {
                  return e2.docId == element.docId;
                }));
          });
          keyToAdd.forEach((key, value) {
            var exist = fullKey[key]!;
            exist.docs.addAll(value.docs);
          });
          if (fullKey.isNotEmpty) {
            await keyValueDb.putMany(
                fullKey.map((key, value) => MapEntry(key, value.toJson())));
          }
          var fullKeyToDelete = Map<ViewKeyMetaKey, ViewValue>.from(fullKey);
          fullKeyToDelete.removeWhere((key, value) => value.docs.length > 0);
          if (fullKeyToDelete.isNotEmpty) {
            await keyValueDb.deleteMany(fullKeyToDelete.keys.toList());
          }
          FoodbDebug.timedEnd('<_generateView>: updateKey');
          if (newDocMetas.isNotEmpty) {
            await keyValueDb.putMany(newDocMetas);
          }
          await keyValueDb.put(ViewMetaKey(key: viewName),
              ViewMeta(lastSeq: decodeSeq(resp.lastSeq!)).toJson());
          if (pending > 0) {
            processChange(resp.lastSeq!);
          } else {
            c.complete();
          }
        });
      }

      processChange(encodeSeq(meta.lastSeq));
      await c.future;
    }
  }

  Future<void> clearView(String designDocName, String viewName) async {
    var view = keyValueDb.getViewTableName(
        designDocId: designDocName, viewId: viewName);
    await keyValueDb.delete(ViewMetaKey(key: view));
    await keyValueDb.clearTable(ViewDocMetaKey(viewName: view, key: '\uffff'));
    await keyValueDb.clearTable(
        ViewKeyMetaKey(viewName: view, key: ViewKeyMeta(key: '\uffff')));
  }

  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewId,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    Doc<DesignDoc>? designDoc;
    final isAllDoc = ddocId == allDocDesignDoc.id;
    if (isAllDoc) {
      designDoc = allDocDesignDoc;
    } else {
      designDoc = await fetchDesignDoc(ddocName: ddocId);
    }

    if (designDoc != null) {
      await _generateView(designDoc);
      var viewName = keyValueDb.getViewTableName(
          designDocId: designDoc.id, viewId: viewId);
      late ReadResult<ViewKeyMetaKey> result;
      if (getViewRequest.keys != null) {
        result = ReadResult(
          totalRows:
              await keyValueDb.tableSize(ViewKeyMetaKey(viewName: viewName)),
          offset: 0,
          records: Map.fromIterable(
            (await Future.wait(
              getViewRequest.keys!.map(
                (e) => keyValueDb.get<ViewKeyMetaKey>(
                  ViewKeyMetaKey(
                    viewName: viewName,
                    key: ViewKeyMeta(
                      key: e,
                    ),
                  ),
                ),
              ),
            ))
                .where((element) => element != null),
            key: (e) =>
                (e as MapEntry<ViewKeyMetaKey, Map<String, dynamic>>).key,
            value: (e) =>
                (e as MapEntry<ViewKeyMetaKey, Map<String, dynamic>>).value,
          ),
        );
      } else {
        result = await keyValueDb.read<ViewKeyMetaKey>(
          ViewKeyMetaKey(viewName: viewName),
          startkey: getViewRequest.startkey == null
              ? null
              : ViewKeyMetaKey(
                  viewName: viewName,
                  key: ViewKeyMeta(
                    key: getViewRequest.startkey,
                  )),
          endkey: getViewRequest.endkey == null
              ? null
              : ViewKeyMetaKey(
                  viewName: viewName,
                  key: ViewKeyMeta(key: getViewRequest.endkey)),
          desc: getViewRequest.descending == true,
          inclusiveEnd: getViewRequest.inclusiveEnd != false,
          inclusiveStart: true,
          limit: getViewRequest.limit,
          skip: getViewRequest.skip,
        );
      }

      var data = result.records.entries.expand((e) =>
          ViewValue.fromJson(e.value).docs.map((d) => MapEntry(e.key, d)));

      List<ViewRow<T>> rows = [];
      Map<String, DocHistory> map = {};
      if (getViewRequest.includeDocs == true) {
        var docs = (await keyValueDb.getMany(data
            .map(
              (e) => DocKey(
                  key: isAllDoc ? e.key.key?.key as String : e.value.docId),
            )
            .toList()));
        docs.removeWhere((key, value) => value == null);
        map = docs.map<String, DocHistory>(
          (key, value) => MapEntry(key.key!, DocHistory.fromJson(value!)),
        );
      }

      for (var r in data) {
        final key = r.key.key!;
        final value = r.value;
        final docId = isAllDoc ? key.key as String : value.docId;
        ViewRow<T> row = ViewRow<T>(
            id: docId,
            key: key.key,
            value: value.value,
            doc: getViewRequest.includeDocs == true
                ? map[docId]!.toDoc<T>(
                    map[docId]!.winner!.rev,
                    fromJsonT,
                    revLimit: _revLimit,
                  )
                : null);
        rows.add(row);
      }

      return GetViewResponse(
          offset: result.offset, totalRows: result.totalRows, rows: rows);
    } else {
      throw AdapterException(error: "Design Doc Not Exists");
    }
  }

  @override
  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    return view<T>(allDocDesignDoc.id, allDocDesignDoc.model.views.keys.first,
        allDocsRequest, fromJsonT);
  }
}
