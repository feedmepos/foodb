part of '../foodb.dart';

mixin _KeyValueGet on _AbstractKeyValue {
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
    var targetRev = rev != null ? Rev.fromString(rev) : result.winner?.rev;
    if (targetRev != null) {
      doc = result.toDoc(targetRev, fromJsonT,
          showRevision: revs,
          showRevInfo: revsInfo || meta,
          showConflicts: conflicts || meta);
    }
    return doc;
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
          id: d.id, rev: d.rev?.toString(), revs: revs, fromJsonT: fromJsonT);
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
