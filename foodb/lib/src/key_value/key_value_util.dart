part of '../../foodb.dart';

mixin _KeyValueUtil on _AbstractKeyValue {
  @override
  Future<GetInfoResponse> info() async {
    print("> couchdb kvu ");
    // need to build index first
    var t0 = DateTime.now().millisecondsSinceEpoch;
    print("> couchdb kvu 1 = " + (DateTime.now().millisecondsSinceEpoch - t0).toString());
    var data = GetViewRequest();
    print("> couchdb kvu 2 = " + (DateTime.now().millisecondsSinceEpoch - t0).toString());
    await allDocs(data, (json) => json);
    print("> couchdb kvu 3 = " + (DateTime.now().millisecondsSinceEpoch - t0).toString());
    return Future.value(GetInfoResponse(
        instanceStartTime: "0",
        updateSeq:
            (await keyValueDb.last(SequenceKey(key: 0)))?.key.toString() ?? "0",
        dbName: dbName,
        docCount: (await keyValueDb
            .tableSize(ViewKeyMetaKey(viewName: keyValueDb.allDocViewName)))));
  }

  @override
  Future<GetServerInfoResponse> serverInfo() async {
    return GetServerInfoResponse(uuid: 'in-memory-db', version: '1');
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) async {
    Map<String, RevsDiff> revsDiff = {};
    var docs = await keyValueDb
        .getMany(body.keys.map((key) => DocKey(key: key)).toList());
    docs.forEach((key, result) {
      DocHistory docHistory = result != null
          ? DocHistory.fromJson(result)
          : new DocHistory(
              id: key.key!, docs: {}, revisions: RevisionTree(nodes: []));
      var diff = docHistory.revsDiff(body[key.key]!.map((e) => e).toList());
      if (diff.missing.isNotEmpty) {
        revsDiff[key.key!] =
            docHistory.revsDiff(body[key.key]!.map((e) => e).toList());
      }
    });
    return revsDiff;
  }

  @override
  Future<bool> initDb() async {
    await keyValueDb.initDb();
    var map = await keyValueDb.get(UtilsKey(key: '_revs_limit'));
    _revLimit = map?.value['_revs_limit'] ?? 1000;
    return true;
  }

  @override
  Future<bool> destroy() async {
    return keyValueDb.destroy();
  }

  @override
  Future<bool> revsLimit(int limit) async {
    _revLimit = limit;
    await keyValueDb.put(UtilsKey(key: '_revs_limit'), {'_revs_limit': limit});
    return true;
  }

  @override
  Future<bool> compact() async {
    var doc = await keyValueDb.get(UtilsKey(key: '_compaction'));
    var meta = doc != null
        ? CompactionMeta.fromJson(doc.value)
        : CompactionMeta(lastSeq: 0, revLimit: _revLimit);

    if (meta.revLimit != _revLimit) {
      meta.lastSeq = 0;
      meta.revLimit = _revLimit;
    }

    var compacting = Completer();

    changesStream(
        ChangeRequest(since: encodeSeq(meta.lastSeq), feed: ChangeFeed.normal),
        onComplete: (resp) async {
      int checkpointSize = 100;
      for (int i = 0; i < resp.results.length; ++i) {
        final change = resp.results[i];
        var docToProcess = DocHistory.fromJson(
            (await keyValueDb.get(DocKey(key: change.id)))!.value);
        await keyValueDb.put(DocKey(key: docToProcess.id),
            docToProcess.compact(meta.revLimit).toJson());
        if (i % checkpointSize == 0) {
          await keyValueDb.put(
              UtilsKey(key: '_compaction'),
              CompactionMeta(
                      lastSeq: decodeSeq(change.seq!), revLimit: meta.revLimit)
                  .toJson());
        }
      }
      await keyValueDb.put(
          UtilsKey(key: '_compaction'),
          CompactionMeta(
                  lastSeq: decodeSeq(resp.lastSeq!), revLimit: meta.revLimit)
              .toJson());
      compacting.complete();
    });

    await compacting.future;
    return true;
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() async {
    return EnsureFullCommitResponse(instanceStartTime: "0", ok: true);
  }
}
