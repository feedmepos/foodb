part of '../foodb.dart';

mixin _KeyValueFind on _AbstractKeyValue {
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
    // PartialFilterSelector generator = new PartialFilterSelector();
    // Map<String, dynamic> newSelector =
    //     generator.generateSelector(findRequest.selector);
    // if (findRequest.sort != null) {
    //   ViewKey? viewKey = await _findSelectorIndexByFields(findRequest.sort!);
    //   if (viewKey != null) {
    //   } else {}
    // }

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
}
