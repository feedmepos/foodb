part of './key_value_adapter.dart';

mixin _KeyValueAdapterView on _KeyValueAdapter {
  String _getViewName({required String designDocId, required String viewId}) {
    return '${designDocId}/_view/$viewId';
  }

  Map<ViewKeyMeta, dynamic> _runMapper(
      AbstracDesignDocView view, String id, InternalDoc? doc) {
    Map<ViewKeyMeta, dynamic> resultMap = Map();
    if (doc != null) {
      if (view is JSDesignDocView) {
        throw UnimplementedError();
      } else if (view is QueryDesignDocView) {
        ///check if partial filter selector !=null
        /// check key got $sign => find its combination_operator
        /// for each key-value stored in combination operators=> conditional-operators-argument, then call conditional operator func
        /// if result = true, output
        // String key = '';
        // bool isValid = true;

        // for (String field in view.map.fields.keys) {
        //   if (doc.data.containsKey(field)) {
        //     key = key + "_" + doc.data[field].toString();
        //   } else if (field == "id") {
        //     key = key + "_" + id;
        //   } else {
        //     isValid = false;
        //     break;
        //   }
        // }
        // if (isValid == true) {
        //   // return [
        //   //   MapEntry(ViewKey(id: id, key: key).toString(),
        //   //       ViewRowValue(rev: doc.rev).toJson())
        //   // ];
        // } else {
        //   return null;
        // }
        throw UnimplementedError();
      } else if (view is AllDocDesignDocView) {
        resultMap.putIfAbsent(
            ViewKeyMeta(key: id, docId: id, index: 0), () => {"rev": doc.rev});
      } else {
        throw new UnimplementedError('Unknown Design Doc View');
      }
    }
    return resultMap;
  }

  Future<void> _generateView(Doc<DesignDoc> designDoc) async {
    for (var e in designDoc.model.views.entries) {
      var view = e.value;
      var viewName = _getViewName(designDocId: designDoc.id, viewId: e.key);
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
                      ViewKeyMetaKey(viewName: viewName, key: key), value)));
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
      String viewName,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    // var viewName = _getViewName(designDocId: ddocId, viewId: viewId);
    // Doc<DesignDoc>? designDoc =
    //     await get(id: ddocId, fromJsonT: (value) => DesignDoc.fromJson(value));
    // if (designDoc != null) {
    //   await _generateView(designDoc);

    //   ReadResult result = await keyValueDb.read(ViewKeyRecord(type: viewName),
    //       startkey: getViewRequest.startkey, endkey: getViewRequest.endkey, desc: getViewRequest.descending);

    //   if ((startKey != null && startKeyDocId != null) ||
    //       (endKey != null && endKeyDocId != null)) {
    //     result.docs.removeWhere((key, value) =>
    //         ((startKeyDocId ?? "").compareTo(ViewKey.fromString(key).id) > 0 ||
    //             (endKeyDocId ?? "\uffff")
    //                     .compareTo(ViewKey.fromString(key).id) <
    //                 0));
    //   }
    //   List<AllDocRow<Map<String, dynamic>>> rows = [];

    //   Map<String, dynamic> map = await keyValueDb.getMany(DocRecord(),
    //       keys: result.docs.entries
    //           .map<String>((e) => ViewKey.fromString(e.key).id)
    //           .toList());
    //   for (var e in result.docs.entries) {
    //     ViewKey key = ViewKey.fromString(e.key);
    //     DocHistory docs = DocHistory.fromJson(map[key.id]);
    //     AllDocRow<Map<String, dynamic>> row = AllDocRow<Map<String, dynamic>>(
    //         id: key.id,
    //         key: key.key,
    //         value: AllDocRowValue.fromJson(e.value['v']),
    //         doc: docs.winner!
    //             .toDoc<Map<String, dynamic>>(docs.id, (value) => value));
    //     rows.add(row);
    //   }

    //   return rows;
    // } else {
    //   throw AdapterException(error: "Design Doc Not Exists");
    // }
    throw new UnimplementedError();
  }

  @override
  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      Map<String, dynamic>? partialFilterSelector,
      bool? partitioned}) async {
    // if (partialFilterSelector == null) {
    //   partialFilterSelector = {};
    // } else {
    //   partialFilterSelector =
    //       PartialFilterSelector().generateSelector(partialFilterSelector);
    // }
    // String timeStamp = DateTime.now().toIso8601String();
    // String uniqueName = crypto.md5.convert(utf8.encode(timeStamp)).toString();

    // if (name == null) {
    //   name = uniqueName;
    // }
    // if (ddoc == null) {
    //   ddoc = "_design/$uniqueName";
    // }
    // Doc<DesignDoc>? doc =
    //     await get(id: ddoc, fromJsonT: (value) => DesignDoc.fromJson(value));

    // QueryDesignDocView queryDesignDoc = QueryDesignDocView(
    //     map: QueryViewMapper(
    //         partialFilterSelector: partialFilterSelector,
    //         fields: Map.fromIterable(indexFields,
    //             key: (item) => item, value: (item) => "asc")),
    //     reduce: "count",
    //     options: QueryViewOptions(
    //         def: QueryViewOptionsDef(
    //             partialFilterSelector: partialFilterSelector,
    //             fields: indexFields)));

    // if (doc == null) {
    //   doc = new Doc<DesignDoc>(
    //       id: ddoc,
    //       model: DesignDoc(language: "query", views: {name: queryDesignDoc}));
    // } else {
    //   doc.model.views[name] = queryDesignDoc;
    // }
    // Doc<Map<String, dynamic>> mappedDoc = Doc<Map<String, dynamic>>.fromJson(
    //     doc.toJson((value) => value.toJson()),
    //     (json) => json as Map<String, dynamic>);

    // PutResponse putResponse = await put(doc: mappedDoc);
    // if (putResponse.ok) {
    //   return IndexResponse(result: "created", id: ddoc, name: name);
    // } else {
    //   throw AdapterException(error: "failed to put design doc");
    // }
    throw new UnimplementedError();
  }

  @override
  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var viewName = _getViewName(designDocId: "all_docs", viewId: "all_docs");
    Doc<DesignDoc> designDoc = new Doc(
        id: "all_docs",
        model: DesignDoc(
            language: 'query', views: {"all_docs": AllDocDesignDocView()}));

    await _generateView(designDoc);

    final result = await keyValueDb.read<ViewKeyMetaKey>(
        ViewKeyMetaKey(viewName: viewName),
        startkey: allDocsRequest.startkey == null
            ? null
            : ViewKeyMetaKey(
                viewName: viewName,
                key: ViewKeyMeta(
                    key: allDocsRequest.startkey,
                    docId: allDocsRequest.startkey,
                    index: 0)),
        endkey: allDocsRequest.endkey == null
            ? null
            : ViewKeyMetaKey(
                viewName: viewName,
                key: ViewKeyMeta(
                    key: allDocsRequest.endkey,
                    docId: allDocsRequest.endkey,
                    index: 0)),
        desc: allDocsRequest.descending);

    // if ((startkey != null && startKeyDocId != null) ||
    //     (endKey != null && endKeyDocId != null)) {
    //   result.docs.removeWhere((key, value) =>
    //       ((startKeyDocId ?? "").compareTo(ViewKey.fromString(key).id) > 0 ||
    //           (endKeyDocId ?? "\uffff")
    //                   .compareTo(ViewKey.fromString(key).id) <
    //               0));
    // }

    List<ViewRow<T>> rows = [];
    Map<String, DocHistory> map = {};
    if (allDocsRequest.includeDocs == true) {
      var docs = (await keyValueDb.getMany(
          result.records.keys.map((e) => DocKey(key: e.key!.docId)).toList()));
      docs.removeWhere((key, value) => value == null);
      map = docs.map<String, DocHistory>(
          (key, value) => MapEntry(key.key!, DocHistory.fromJson(value!)));
    }

    for (var r in result.records.entries) {
      ViewKeyMeta key = r.key.key!;
      ViewRow<T> row = ViewRow<T>(
          id: key.docId,
          key: key.key,
          value: r.value,
          doc: allDocsRequest.includeDocs == true
              ? map[key.docId]!.toDoc<T>(map[key.docId]!.winner!.rev, fromJsonT)
              : null);
      rows.add(row);
    }

    return GetViewResponse(
        offset: result.offset, totalRows: result.totalRows, rows: rows);
  }
}
