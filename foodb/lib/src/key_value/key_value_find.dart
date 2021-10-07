part of '../../foodb.dart';

mixin _KeyValueFind on _AbstractKeyValue implements _KeyValueView {
  //Position Order Considered
  // Future<ViewKey?> _findSelectorIndexByFields(
  //     List<Map<String, String>> sort) async {
  // ReadResult readResult = await keyValueDb.read(DocKey(key: ''),
  //     startkey: DocKey(key: "_design/"),
  //     endkey: DocKey(key: "_design\ufff0"));
  // List<String> keys = sort.map<String>((e) => e.keys.toList()[0]).toList();

  // Map<ViewKey, int> matchedPositions = {};
  // List<Doc<DesignDoc>> docs = readResult.records.values
  //     .map((e) => Doc.fromJson(
  //         e, (json) => DesignDoc.fromJson(json as Map<String, dynamic>)))
  //     .toList();
  // docs.forEach((doc) {
  //   doc.model.views.forEach((key, value) {
  //     ViewKey viewKey = ViewKey(id: doc.id, key: key);
  //     if (value is QueryDesignDocView) {
  //       if (keys.length == value.options.def.fields.length) {
  //         matchedPositions[viewKey] = 0;
  //         for (int x = 0; x < keys.length; x++) {
  //           if (keys[x] == value.options.def.fields[x]) {
  //             matchedPositions[viewKey] = matchedPositions[viewKey]! + 1;
  //           } else {
  //             matchedPositions.remove(viewKey);
  //           }
  //         }
  //       }
  //     }
  //   });
  // });

  // List<ViewKey>? matchedViewKey = matchedPositions.entries
  //     .where((element) => element.value == keys.length)
  //     .map((e) => e.key)
  //     .toList();

  // if (matchedViewKey.length > 0) {
  //   return matchedViewKey[0];
  // }
  // return null;
  //   throw UnimplementedError();
  // }

  @override
  Future<IndexResponse> createIndex(
      {required QueryViewOptionsDef index,
      String? ddoc,
      String? name,
      String type = 'json',
      bool? partitioned}) async {
    String timeStamp = DateTime.now().toIso8601String();
    String viewName = name ??
        crypto.md5.convert(utf8.encode(jsonEncode(index.toJson()))).toString();
    String ddocName =
        "_design/${ddoc ?? crypto.md5.convert(utf8.encode(timeStamp)).toString()}";

    Doc<DesignDoc>? doc = await get(
        id: ddocName, fromJsonT: (value) => DesignDoc.fromJson(value));

    QueryDesignDocView queryDesignDoc = QueryDesignDocView(
        map: QueryViewMapper(
            fields: Map.fromIterable(index.fields,
                key: (item) => item, value: (item) => "asc")),
        reduce: "_count",
        options: QueryViewOptions(def: index));

    if (doc == null) {
      doc = new Doc<DesignDoc>(
          id: ddocName,
          model:
              DesignDoc(language: "query", views: {viewName: queryDesignDoc}));
    } else {
      doc.model.views[viewName] = queryDesignDoc;
    }
    Doc<Map<String, dynamic>> mappedDoc = Doc<Map<String, dynamic>>.fromJson(
        doc.toJson((value) => value.toJson()),
        (json) => json as Map<String, dynamic>);

    PutResponse putResponse = await put(doc: mappedDoc);
    if (putResponse.ok) {
      return IndexResponse(result: "created", id: ddocName, name: viewName);
    } else {
      throw AdapterException(error: "failed to put design doc");
    }
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    throw UnimplementedError();
  }

  @override
  Future<FindResponse<T>> find<T>(FindRequest findRequest,
      T Function(Map<String, dynamic> p1) toJsonT) async {
    List<String> inputKeys = findRequest.selector.keys();
    MapEntry<String, Doc<DesignDoc>> selectedView =
        await _pickDesignDoc(inputKeys);
    _generateView(selectedView.value);

    var viewName = getViewName(
        designDocId: selectedView.value.id, viewId: selectedView.key);

    final result = await keyValueDb.read<ViewKeyMetaKey>(
        ViewKeyMetaKey(viewName: viewName),
        desc: false,
        inclusiveEnd: true,
        inclusiveStart: true);
    AbstracDesignDocView docView =
        selectedView.value.model.views[selectedView.key]!;

    List<String> docFields;
    if (docView is QueryDesignDocView) {
      docFields = docView.options.def.fields;
    } else {
      docFields = ["_id"];
    }
    Operator indexOperator = _getOperator(findRequest.selector, docFields);

    Map<ViewKeyMetaKey, Map<String, dynamic>> filteredIndex = {};
    result.records.forEach((key, value) {
      Map<String, dynamic> values = Map.fromIterables(docFields, key.key!.key is List ?key.key!.key: [key.key!.key]);
      if (indexOperator.evaluate(values)) {
        filteredIndex[key] = value;
      }
    });

    var map = (await keyValueDb.getMany(
        result.records.keys.map((e) => DocKey(key: e.key!.docId)).toList()));
    map.removeWhere((key, value) => value == null);
    var docHistories = map.values.map((value) => DocHistory.fromJson(value!));

    List<Doc<T>> finalDocs = [];
    docHistories.forEach((history) {
      if (!findRequest.selector.evaluate(history.winner!.toJson())) {
        finalDocs.add(history.toDoc(history.winner!.rev, toJsonT)!);
      }
    });

    return FindResponse(docs: finalDocs);
  }

  Operator _getOperator(Operator selector, List<String> fields) {
    final indexOperator = AndOperator();
    if (selector is AndOperator) {
      selector.operators.forEach((op) {
        if (op is ConditionOperator) {
          if (fields.contains(op.key)) {
            indexOperator.operators.add(op);
          }
        }
      });
    } else if (selector is ConditionOperator) {
      if (fields.contains(selector.key)) {
        indexOperator.operators.add(selector);
      }
    }

    return indexOperator;
  }

  Future<MapEntry<String, Doc<DesignDoc>>> _pickDesignDoc(
      List<String> inputKeys) async {
    List<Doc<DesignDoc>> docs = await fetchAllDesignDocs();
    Doc<DesignDoc>? winnerDoc;
    String? winnerViewId;
    bool broke = false;
    int maxLength = 0;

    for (Doc<DesignDoc> doc in docs) {
      for (MapEntry entry in doc.model.views.entries) {
        if (entry.value is QueryDesignDocView) {
          List<String> fields = entry.value.options.def.fields;
          if (fields.length <= inputKeys.length + 1) {
            bool allMatched = true;
            for (String field in fields) {
              if (!inputKeys.contains(field) && field != "_id") {
                allMatched = false;
                break;
              }
            }
            if (allMatched) {
              int withIds = fields.length;
              fields.removeWhere((element) => element == "_id");
              int withoutIds = fields.length;

              if (withoutIds > maxLength) {
                winnerViewId = entry.key;
                winnerDoc = doc;
                if (withIds == inputKeys.length) {
                  broke = true;
                  break;
                }
              }
            }
          }
        }
      }
      if (broke == true) {
        break;
      }
    }
    if (winnerViewId == null || winnerDoc == null) {
      return MapEntry("all_docs", allDocDesignDoc);
    }
    return MapEntry(winnerViewId, winnerDoc);
  }
}
