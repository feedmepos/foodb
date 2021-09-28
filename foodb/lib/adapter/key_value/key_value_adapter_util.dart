part of './key_value_adapter.dart';

mixin _KeyValueAdapterUtil on _KeyValueAdapter {
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
  Future<EnsureFullCommitResponse> ensureFullCommit() async {
    return EnsureFullCommitResponse(instanceStartTime: "0", ok: true);
  }
}
