part of '../../foodb.dart';

mixin _KeyValueView on _AbstractKeyValue {
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
      Completer<String> c = new Completer();
      changesStream(
          ChangeRequest(
              since: encodeSeq(meta.lastSeq),
              feed: ChangeFeed.normal), onComplete: (resp) async {
        List<String> docIdToProcess = resp.results.map((e) => e.id).toList();
        final docsToProcess = (await keyValueDb.getMany<DocKey>(
            docIdToProcess.map<DocKey>((k) => DocKey(key: k)).toList()));

        for (var docEntry in docsToProcess.entries) {
          if (docEntry.value == null) continue;
          var history = DocHistory.fromJson(docEntry.value!);
          var existViewDocMeta = await keyValueDb.get<ViewDocMetaKey>(
              ViewDocMetaKey(viewName: viewName, key: history.id));
          if (existViewDocMeta != null) {
            var viewDocMeta = ViewDocMeta.fromJson(existViewDocMeta.value);
            List<ViewKeyMeta> keysForDelete = viewDocMeta.keys;
            for (final k in keysForDelete) {
              var viewKey = ViewKeyMetaKey(key: k, viewName: viewName);
              var exist = await keyValueDb.get(viewKey);
              if (exist != null) {
                var viewValue = ViewValue.fromJson(exist.value);
                var newDocs = viewValue.docs
                    .where((element) => element.docId != history.id);
                if (newDocs.length == 0) {
                  await keyValueDb.delete(viewKey);
                } else {
                  await keyValueDb.put(
                      viewKey, ViewValue(docs: newDocs.toList()).toJson());
                }
              }
            }

            await keyValueDb
                .delete(ViewDocMetaKey(viewName: viewName, key: history.id));
          }

          if (history.winner != null) {
            var entries = _runMapper(view, history.id, history.winner);
            //change to put in batch
            for (final e in entries.entries) {
              var key = ViewKeyMetaKey(viewName: viewName, key: e.key);
              var exist = await keyValueDb.get(key);
              var value = ViewValue(docs: []);
              if (exist != null) {
                value = ViewValue.fromJson(exist.value);
              }
              value.docs.add(e.value);
              await keyValueDb.put(key, value.toJson());
            }
            if (entries.isNotEmpty) {}

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
    String fullDdocId = "_design/$ddocId";
    Doc<DesignDoc>? designDoc;
    final isAllDoc = ddocId == allDocDesignDoc.id;
    if (isAllDoc) {
      designDoc = allDocDesignDoc;
    } else {
      designDoc = await fetchDesignDoc(id: fullDdocId);
    }

    if (designDoc != null) {
      await _generateView(designDoc);
      var viewName = getViewName(designDocId: designDoc.id, viewId: viewId);
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
