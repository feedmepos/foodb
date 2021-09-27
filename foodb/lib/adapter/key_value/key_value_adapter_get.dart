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
    var json = await keyValueDb.get(DocRecord(), key: id);
    if (json == null) {
      return null;
    }
    var result = DocHistory.fromJson(json);
    return result.winner?.toDoc(id, fromJsonT);
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

    var json = await keyValueDb.get(DocRecord(), key: id);
    if (json == null) {
      return [];
    }
    var docHistory = DocHistory.fromJson(json);
    if (openRevs.all) {
      return docHistory.docs.values
          .map((e) => e.toDoc(id, (json) => fromJsonT(json),
              revisions: revs ? docHistory.getRevision(e.rev) : null))
          .toList();
    } else {
      List<Doc<T>> list = [];
      openRevs.revs.forEach((rev) {
        if (docHistory.docs.containsKey(rev)) {
          list.add(docHistory.docs[rev]!.toDoc(id, (json) => fromJsonT(json),
              revisions:
                  revs ? docHistory.getRevision(Rev.fromString(rev)) : null));
        }
      });
      return list;
    }
  }

  @override
  Future<BulkGetResponse<T>> bulkGet<T>(
      {required List<Map<String, dynamic>> body,
      bool revs = false,
      bool latest = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) {
    throw UnimplementedError();
  }
}
