part of './key_value_adapter.dart';

mixin _KeyValueAdapterFind on _KeyValueAdapter {
  //Position Order Considered
  Future<ViewKey?> _findSelectorIndexByFields(
      List<Map<String, String>> sort) async {
    ReadResult readResult = await keyValueDb.read(DocKey(key: ''),
        startkey: DocKey(key: "_design/"),
        endkey: DocKey(key: "_design\uffff"));
    List<String> keys = sort.map<String>((e) => e.keys.toList()[0]).toList();

    Map<ViewKey, int> matchedPositions = {};
    List<Doc<DesignDoc>> docs = readResult.records.values
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

  @override
  Future<FindResponse<T>> find<T>(
      FindRequest findRequest, T Function(Map<String, dynamic> p1) toJsonT) {
    // TODO: implement find
    // regenerateView
    // get result from view
    throw UnimplementedError();
  }
}
