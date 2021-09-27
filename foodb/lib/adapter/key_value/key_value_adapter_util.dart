part of './key_value_adapter.dart';

mixin _KeyValueAdapterUtil on _KeyValueAdapter {
  @override
  Future<GetInfoResponse> info() async {
    return Future.value(GetInfoResponse(
        instanceStartTime: "0",
        updateSeq:
            (await keyValueDb.last(SequenceRecord()))?.key.toString() ?? "0",
        dbName: dbName));
  }

  @override
  Future<GetServerInfoResponse> serverInfo() {
    // TODO: implement serverInfo
    throw UnimplementedError();
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) async {
    Map<String, RevsDiff> revsDiff = {};
    await Future.forEach(body.keys, (String key) async {
      var result = await keyValueDb.get(DocRecord(), key: key);
      DocHistory docHistory = result != null
          ? DocHistory.fromJson((await keyValueDb.get(DocRecord(), key: key))!)
          : new DocHistory(
              id: key, docs: {}, revisions: RevisionTree(nodes: []));
      revsDiff[key] = docHistory
          .revsDiff(body[key]!.map((e) => Rev.fromString(e)).toList());
    });
    return revsDiff;
  }

  @override
  Future<bool> initDb() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> destroy() async {
    return await keyValueDb.deleteDatabase();
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() {
    return Future.value(
        EnsureFullCommitResponse(instanceStartTime: "0", ok: true));
  }
}
