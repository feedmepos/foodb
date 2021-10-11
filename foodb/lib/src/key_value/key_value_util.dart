part of '../../foodb.dart';

mixin _KeyValueUtil on _AbstractKeyValue {
  @override
  Future<GetInfoResponse> info() async {
    return Future.value(GetInfoResponse(
        instanceStartTime: "0",
        updateSeq:
            (await keyValueDb.last(SequenceKey(key: 0)))?.key.toString() ?? "0",
        dbName: dbName));
  }

  @override
  Future<GetServerInfoResponse> serverInfo() async {
    return GetServerInfoResponse(uuid: 'in-memory-db', version: '1');
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) async {
    Map<String, RevsDiff> revsDiff = {};
    await Future.forEach(body.keys, (String key) async {
      var result = await keyValueDb.get(DocKey(key: key));
      DocHistory docHistory = result != null
          ? DocHistory.fromJson(result.value)
          : new DocHistory(
              id: key, docs: {}, revisions: RevisionTree(nodes: []));
      revsDiff[key] = docHistory.revsDiff(body[key]!.map((e) => e).toList());
    });
    return revsDiff;
  }

  @override
  Future<bool> initDb() async {
    return keyValueDb.initDb();
  }

  @override
  Future<bool> destroy() async {
    return keyValueDb.destroy();
  }

  @override
  Future<bool> revsLimit(int limit) async {
    await keyValueDb.put(UtilsKey(key: '_revs_limit'), {'_revs_limit': limit});
    return true;
  }

  @override
  Future<bool> compact() async {
    var map = await keyValueDb.get(UtilsKey(key: '_revs_limit'));
    int limit = map?.value['_revs_limit'] ?? 1000;

    ReadResult<DocKey> result = await keyValueDb.read<DocKey>(DocKey(),
        desc: false, inclusiveStart: true, inclusiveEnd: true);
    Map<DocKey, Map<String, dynamic>> histories =
        result.records.map((key, value) {
      DocHistory history = DocHistory.fromJson(value);
      history.compact(limit);

      return MapEntry(key, history.toJson());
    });

    return await keyValueDb.putMany(histories);
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() async {
    return EnsureFullCommitResponse(instanceStartTime: "0", ok: true);
  }
}
