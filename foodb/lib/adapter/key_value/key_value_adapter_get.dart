part of './key_value_adapter.dart';

mixin _KeyValueAdapterGet on _KeyValueAdapter {
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
    var entry = await keyValueDb.get(DocKey(key: id));
    if (entry == null) {
      return null;
    }
    var result = DocHistory.fromJson(entry.value);
    Doc<T>? doc;
    if (rev != null) {
      result.toDoc(Rev.fromString(rev), (json) => json);
    } else {
      result.toDoc(result.winner!.rev, (json) => json);
    }
    return doc;
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

    var entry = await keyValueDb.get(DocKey(key: id));
    if (entry == null) {
      return [];
    }
    var docHistory = DocHistory.fromJson(entry.value);
    if (openRevs.all) {
      return docHistory.docs.values
          .map((e) => docHistory.toDoc<T>(e.rev, fromJsonT, revs: revs))
          .toList();
    } else {
      List<Doc<T>> list = [];
      openRevs.revs.forEach((rev) {
        if (docHistory.docs.containsKey(rev)) {
          list.add(
              docHistory.toDoc<T>(Rev.fromString(rev), fromJsonT, revs: revs));
        }
      });
      return list;
    }
  }

  @override
  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    List<BulkGetIdDocs<T>> results = [];
    for (final d in body.docs) {
      late BulkGetDoc<T> doc;
      final found = await get(
          id: d.id,
          rev: d.rev.toString(),
          revsInfo: true,
          fromJsonT: fromJsonT);
      if (found == null) {
        doc = BulkGetDoc(
            error: BulkGetDocError(
                id: d.id,
                rev: d.rev?.toString() ?? 'undefined',
                error: 'not_found',
                reason: 'missing'));
      } else {
        doc = BulkGetDoc(doc: found);
      }
      results.add(BulkGetIdDocs(id: d.id, docs: [doc]));
    }

    return BulkGetResponse(results: results);
  }
}
