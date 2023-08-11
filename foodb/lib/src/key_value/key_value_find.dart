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

    Doc<DesignDoc>? doc;
    try {
      doc = await get(
          id: ddocName, fromJsonT: (value) => DesignDoc.fromJson(value));
    } on AdapterException catch (ex) {
      if (!(ex.reason!.contains('missing') || ex.reason!.contains('deleted')))
        rethrow;
    }

    QueryDesignDocView queryDesignDoc = QueryDesignDocView(
        map: QueryViewMapper(
            fields: Map.fromIterable(index.fields,
                key: (item) => item, value: (item) => "asc")),
        reduce: "_count",
        options: QueryViewOptions(def: index));

    var exist = false;
    if (doc == null) {
      doc = new Doc<DesignDoc>(
          id: ddocName,
          model:
              DesignDoc(language: "query", views: {viewName: queryDesignDoc}));
    } else {
      if (doc.model.views.containsKey(viewName)) {
        exist = true;
      } else {
        doc.model.views[viewName] = queryDesignDoc;
      }
    }
    Doc<Map<String, dynamic>> mappedDoc = Doc<Map<String, dynamic>>.fromJson(
        doc.toJson((value) => value.toJson()),
        (json) => json as Map<String, dynamic>);

    if (!exist) {
      PutResponse putResponse = await put(doc: mappedDoc);
      if (putResponse.ok) {
        return IndexResponse(result: "created", id: ddocName, name: viewName);
      } else {
        throw AdapterException(error: "failed to put design doc");
      }
    } else {
      return IndexResponse(result: "exists", id: ddocName, name: viewName);
    }
  }

  @override
  Future<DeleteIndexResponse> deleteIndex({
    required String ddoc,
    required String name,
  }) async {
    final Doc<DesignDoc> designDoc;
    final MapEntry<String, AbstracDesignDocView> view;
    try {
      designDoc = (await fetchDesignDoc(ddocName: ddoc));
      view = designDoc.model.views.entries
          .firstWhere((element) => element.key == name);
      if (view.value.runtimeType != QueryDesignDocView) {
        throw Exception('invalid design doc');
      }
    } catch (err) {
      throw AdapterException(error: 'index not found');
    }
    var newViews =
        Map<String, AbstracDesignDocView>.from(designDoc.model.views);
    newViews.removeWhere((key, value) => key == name);
    await clearView(designDoc.id, name);
    if (newViews.isNotEmpty) {
      await put(
          doc: Doc<Map<String, dynamic>>.fromJson(
              designDoc.toJson((value) => value.toJson()),
              (json) => json as Map<String, dynamic>));
      await _generateView(designDoc);
    } else {
      await delete(id: designDoc.id, rev: designDoc.rev!);
    }
    return DeleteIndexResponse(ok: true);
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    MapEntry<String, Doc<DesignDoc>> selectedView =
        await _pickDesignDoc(findRequest.selector.keys().toSet());

    final view = selectedView.value.model.views[selectedView.key];
    return ExplainResponse(
        index: Index(
            ddoc: selectedView.value.id,
            name: selectedView.key,
            type: "json",
            def: view is QueryDesignDocView ? view.map.fields : {"_id": "asc"}),
        selector: findRequest.toJson(),
        opts: Opts(
            conflicts: findRequest.conflicts,
            r: [findRequest.r],
            useIndex: [],
            bookmark: findRequest.bookmark ?? "nil",
            limit: findRequest.limit ?? 25,
            skip: findRequest.skip ?? 0,
            sort: findRequest.sort,
            fields: findRequest.fields ?? "all_fields"),
        limit: findRequest.limit ?? 25,
        skip: findRequest.skip ?? 0,
        fields: findRequest.fields ?? "all_fields");
  }

  @override
  Future<FindResponse<T>> find<T>(FindRequest findRequest,
      T Function(Map<String, dynamic> p1) fromJsonT) async {
    final selector = findRequest.selector;
    late MapEntry<String, Doc<DesignDoc>> selectedView;
    selectedView = await _pickDesignDoc(selector.keys().toSet());
    await _generateView(selectedView.value);
    var viewName = keyValueDb.getViewTableName(
        designDocId: selectedView.value.id, viewId: selectedView.key);

    late ReadResult<ViewKeyMetaKey> result;
    late AbstracDesignDocView docView;
    result = await keyValueDb.read<ViewKeyMetaKey>(
        ViewKeyMetaKey(viewName: viewName),
        startkey: ViewKeyMetaKey(viewName: viewName),
        endkey: ViewKeyMetaKey(viewName: viewName),
        desc: false,
        inclusiveEnd: true,
        inclusiveStart: true);
    docView = selectedView.value.model.views[selectedView.key]!;

    List<String> docFields;
    if (docView is QueryDesignDocView) {
      docFields = (docView as QueryDesignDocView).options.def.fields;
    } else {
      docFields = ["_id"];
    }

    Operator indexOperator = _getOperator(selector, docFields);

    List<String> filteredIndex = [];
    result.records.forEach((key, value) {
      Map<String, dynamic> values = Map.fromIterables(
          docFields, key.key!.key is List ? key.key!.key : [key.key!.key]);
      if (indexOperator.evaluate(values)) {
        final viewValue = ViewValue.fromJson(value);
        viewValue.docs.forEach((doc) {
          filteredIndex.add(doc.docId);
        });
      }
    });

    late Map<DocKey, Map<String, dynamic>?> map;
    map = (await keyValueDb
        .getMany(filteredIndex.map((e) => DocKey(key: e)).toList()));
    map.removeWhere((key, value) => value == null);
    var docHistories = map.values.map((value) => DocHistory.fromJson(value!));

    List<Doc<T>> finalDocs = [];
    docHistories.forEach((history) {
      var doc = history.winner!.data;
      doc['_id'] = history.id;
      if (selector.evaluate(doc)) {
        finalDocs.add(history.toDoc(
          history.winnerRev!,
          fromJsonT,
          revLimit: _revLimit,
        )!);
      }
    });
    // if (findRequest.sort != null) {
    //   finalDocs.sort((a, b) {
    //     for (Map<String, String> entry in findRequest.sort!) {
    //       entry.forEach((key, value) {
    //         int compare = a.toJson((value) => null)
    //       });
    //     }
    //   });
    // }
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
      Set<String> inputKeys) async {
    List<Doc<DesignDoc>> docs = await fetchAllDesignDocs();
    Doc<DesignDoc>? winnerDoc;
    String? winnerViewId;
    bool broke = false;
    int maxLength = 0;

    for (Doc<DesignDoc> doc in docs) {
      for (MapEntry entry in doc.model.views.entries) {
        if (entry.value is QueryDesignDocView) {
          Set<String> fields = entry.value.options.def.fields.toSet();
          Set<String> matchingFields = inputKeys.contains("_id")
              ? fields
              : fields.where((element) => element != "_id").toSet();

          //design docs fields less or equal to selector keys
          if (matchingFields.length <= inputKeys.length) {
            bool allMatched = true;
            for (String field in matchingFields) {
              if (!inputKeys.contains(field)) {
                allMatched = false;
                break;
              }
            }
            if (allMatched) {
              if (matchingFields.length > maxLength) {
                winnerViewId = entry.key;
                winnerDoc = doc;
                if (matchingFields.length == inputKeys.length) {
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
