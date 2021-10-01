part of '../foodb.dart';

mixin _KeyValueView on _AbstractKeyValue {
  Map<ViewKeyMeta, dynamic> _runMapper(
      AbstracDesignDocView view, String id, InternalDoc? doc) {
    Map<ViewKeyMeta, dynamic> resultMap = Map();
    if (doc != null) {
      if (view is JSDesignDocView) {
        throw UnimplementedError();
      } else if (view is QueryDesignDocView) {
        final keysToIndex = view.map.fields.keys;
        final objectKeys =
            doc.data.keys.where((element) => keysToIndex.contains(element));
        // object missing key, do not index;
        if (objectKeys.length < keysToIndex.length) {
          return resultMap;
        }
        resultMap.putIfAbsent(
            ViewKeyMeta(
                key: keysToIndex.map((e) => doc.data[e]).toList(), docId: id),
            () => null);
        return resultMap;
      } else if (view is AllDocDesignDocView) {
        resultMap.putIfAbsent(
            ViewKeyMeta(key: id), () => {"rev": doc.rev.toString()});
      } else {
        throw new UnimplementedError('Unknown Design Doc View');
      }
    }
    return resultMap;
  }

  Future<void> _generateView(Doc<DesignDoc> designDoc) async {
    for (var e in designDoc.model.views.entries) {
      var view = e.value;
      var viewName = getViewName(designDocId: designDoc.id, viewId: e.key);
      var json = (await keyValueDb.get(ViewMetaKey(key: viewName)))?.value;

      ViewMeta meta;
      if (json == null) {
        meta = ViewMeta(lastSeq: 0);
      } else {
        meta = ViewMeta.fromJson(json);
      }
      var stream = await changesStream(ChangeRequest(
          since: encodeSeq(meta.lastSeq), feed: ChangeFeed.normal));
      Completer<String> c = new Completer();
      stream.listen(
          onResult: (result) => {},
          onComplete: (resp) async {
            List<String> docIdToProcess =
                resp.results.map((e) => e.id).toList();
            final docsToProcess = (await keyValueDb.getMany<DocKey>(
                docIdToProcess.map<DocKey>((k) => DocKey(key: k)).toList()));

            for (var entry in docsToProcess.entries) {
              if (entry.value == null) continue;
              var history = DocHistory.fromJson(entry.value!);
              var existViewDocMeta = await keyValueDb.get<ViewDocMetaKey>(
                  ViewDocMetaKey(viewName: viewName, key: history.id));
              if (existViewDocMeta != null) {
                var viewDocMeta = ViewDocMeta.fromJson(existViewDocMeta.value);
                List<ViewKeyMeta> keysForDelete = viewDocMeta.keys;
                await keyValueDb.deleteMany(keysForDelete
                    .map((k) => ViewKeyMetaKey(key: k, viewName: viewName))
                    .toList());
                await keyValueDb.delete(
                    ViewDocMetaKey(viewName: viewName, key: history.id));
              }

              if (history.winner != null) {
                var entries = _runMapper(view, history.id, history.winner);
                //change to put in batch
                if (entries.isNotEmpty) {
                  await keyValueDb.putMany(entries.map((key, value) => MapEntry(
                      ViewKeyMetaKey(viewName: viewName, key: key),
                      ViewValue(value).toJson())));
                }

                await keyValueDb.put(
                    ViewDocMetaKey(viewName: viewName, key: history.id),
                    ViewDocMeta(keys: entries.keys.toList()).toJson());
              }
            }

            c.complete(resp.lastSeq);
          });

      var lastSeq = await c.future;
      await keyValueDb.put(ViewMetaKey(key: viewName),
          ViewMeta(lastSeq: decodeSeq(lastSeq)).toJson());
    }
  }

  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewId,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    ddocId = "_design/$ddocId";
    var viewName = getViewName(designDocId: ddocId, viewId: viewId);
    Doc<DesignDoc>? designDoc;
    final isAllDoc = viewName == allDocViewName;
    if (isAllDoc) {
      designDoc = allDocDesignDoc;
    } else {
      designDoc = await get(
          id: ddocId, fromJsonT: (value) => DesignDoc.fromJson(value));
    }

    if (designDoc != null) {
      await _generateView(designDoc);

      final result = await keyValueDb.read<ViewKeyMetaKey>(
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
          inclusiveStart: true);

      List<ViewRow<T>> rows = [];
      Map<String, DocHistory> map = {};
      if (getViewRequest.includeDocs == true) {
        var docs = (await keyValueDb.getMany(result.records.keys
            .map((e) => DocKey(key: e.key!.docId))
            .toList()));
        docs.removeWhere((key, value) => value == null);
        map = docs.map<String, DocHistory>(
            (key, value) => MapEntry(key.key!, DocHistory.fromJson(value!)));
      }

      for (var r in result.records.entries) {
        ViewKeyMeta key = r.key.key!;
        final docId = isAllDoc ? key.key as String : key.docId as String;
        ViewRow<T> row = ViewRow<T>(
            id: docId,
            key: key.key,
            value: ViewValue.fromJson(r.value).value,
            doc: getViewRequest.includeDocs == true
                ? map[docId]!.toDoc<T>(map[docId]!.winner!.rev, fromJsonT)
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
    return view<T>(allDocDesignDocId, allDocViewId, allDocsRequest, fromJsonT);
  }
}
