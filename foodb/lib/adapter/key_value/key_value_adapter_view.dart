part of './key_value_adapter.dart';

mixin _KeyValueAdapterView on _KeyValueAdapter {
  String _getViewName({required String designDocId, required String viewId}) {
    return '${designDocId}_$viewId';
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

  Future<void> _generateView(Doc<DesignDoc> designDoc) async {
    for (var e in designDoc.model.views.entries) {
      var view = e.value;
      var viewName = _getViewName(designDocId: designDoc.id, viewId: e.key);
      var json = await keyValueDb.get(ViewMetaRecord(), key: viewName);

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
                await keyValueDb.getMany(DocRecord(), keys: keys);
            for (var id in keys) {
              var history = DocHistory.fromJson(mapResults[id]);
              Map<String, dynamic>? viewId = await keyValueDb
                  .get(ViewIdRecord(type: viewName), key: history.id);
              if (viewId != null) {
                List<String> keysForDelete = [];

                var viewDocMeta = ViewDocMeta.fromJson(viewId);
                for (var key in viewDocMeta.keys) {
                  keysForDelete.add(key);
                }
                await keyValueDb.delete(
                  ViewIdRecord(type: viewName),
                  key: history.id,
                );
                await keyValueDb.deleteMany(ViewKeyRecord(type: viewName),
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
                  await keyValueDb.insert(
                    ViewIdRecord(type: viewName),
                    key: history.id,
                    object:
                        ViewDocMeta(keys: entries.map((e) => e.key).toList())
                            .toJson(),
                  );

                  await keyValueDb.insertMany(
                    ViewKeyRecord(type: viewName),
                    objects: mapForInsert,
                  );
                }
              }
            }

            c.complete(resp.lastSeq);
          });

      var lastSeq = await c.future;
      await keyValueDb.put(ViewMetaRecord(),
          key: viewName, object: ViewMeta(lastSeq: lastSeq).toJson());
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

      ReadResult result = await keyValueDb.read(ViewKeyRecord(type: viewName),
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

      Map<String, dynamic> map = await keyValueDb.getMany(DocRecord(),
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
  Future<GetAllDocsResponse<T>> allDocs<T>(GetAllDocsRequest allDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    var viewName = _getViewName(designDocId: '_all_docs', viewId: '_all_docs');

    await _generateView(Doc<DesignDoc>(
        id: '_all_docs',
        model: DesignDoc(views: {'_all_docs': AllDocDesignDocView()})));

    ReadResult result = await keyValueDb.read(ViewKeyRecord(type: viewName),
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
      mappedDocs = await keyValueDb.getMany(DocRecord(),
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
}
