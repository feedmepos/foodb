part of '../../foodb.dart';

mixin _KeyValueGet on _AbstractKeyValue {
  @override
  Future<Doc<T>> get<T>(
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
    AbstractKey baseKey;
    if (id.startsWith('_local/')) {
      baseKey = LocalDocKey(key: id);
    } else {
      baseKey = DocKey(key: id);
    }
    var entry = await keyValueDb.get(baseKey);
    if (entry == null) {
      throw AdapterException(error: "not_found", reason: ("missing key" + baseKey.toString()));
    }
    var result = DocHistory.fromJson(entry.value);
    Doc<T>? doc;
    if (rev == null && result.winner == null) {
      throw AdapterException(error: "not_found", reason: "deleted");
    }
    var targetRev = rev != null ? Rev.fromString(rev) : result.winner!.rev;
    doc = result.toDoc(
      targetRev,
      fromJsonT,
      showRevision: revs,
      showRevInfo: rev == null && (revsInfo || meta),
      showConflicts: rev == null && (conflicts || meta),
      revLimit: _revLimit,
    );
    if (doc == null) {
      throw AdapterException(error: "not_found", reason: "missing");
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
      var entry = await keyValueDb.get(DocKey(key: d.id));
      if (entry == null) {
        doc = BulkGetDoc(
            error: BulkGetDocError(
                id: d.id,
                rev: d.rev?.toString() ?? 'undefined',
                error: 'not_found',
                reason: 'missing'));
      } else {
        var result = DocHistory.fromJson(entry.value);
        var targetRev = d.rev ?? result.winnerWithDeleted!.rev;
        var resultDoc = result.toDoc(
          targetRev,
          fromJsonT,
          showRevision: revs,
          showRevInfo: false,
          showConflicts: false,
          revLimit: _revLimit,
        );
        if (resultDoc != null) {
          doc = BulkGetDoc(doc: resultDoc);
        } else {
          doc = BulkGetDoc(
            error: BulkGetDocError(
              id: d.id,
              rev: d.rev?.toString() ?? 'undefined',
              error: 'not_found',
              reason: 'missing',
            ),
          );
        }
      }
      results.add(BulkGetIdDocs(id: d.id, docs: [doc]));
    }

    return BulkGetResponse(results: results);
  }
}
