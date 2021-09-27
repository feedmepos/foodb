class ReadResult {
  int totalRows;
  int offset;
  Map<AbstractKey, Map<String, dynamic>> records;
  ReadResult({
    required this.totalRows,
    required this.offset,
    required this.records,
  });
}

abstract class AbstractKey<T extends Comparable> implements Comparable {
  T key;
  final String tableName;
  AbstractKey({
    required this.key,
    required this.tableName,
  });
  AbstractKey copyWithKey({required T newKey});
  int compareTo(other) {
    if (other is AbstractKey) {
      return key.compareTo(other.key);
    }
    return -1;
  }
}

class DocRecord extends AbstractKey<String> {
  DocRecord({required String key}) : super(key: key, tableName: "doc");
  @override
  copyWithKey({required String newKey}) {
    return DocRecord(key: newKey);
  }
}

class LocalDocRecord extends AbstractKey<String> {
  LocalDocRecord({required String key})
      : super(key: key, tableName: "local_doc");
  @override
  copyWithKey({required String newKey}) {
    return LocalDocRecord(key: newKey);
  }
}

class SequenceRecord extends AbstractKey<int> {
  SequenceRecord({required int key}) : super(key: key, tableName: "sequence");
  @override
  copyWithKey({required int newKey}) {
    return SequenceRecord(key: newKey);
  }
}

class ViewMetaRecord extends AbstractKey<String> {
  ViewMetaRecord({required String key})
      : super(key: key, tableName: "view_meta");
  @override
  copyWithKey({required String newKey}) {
    return ViewMetaRecord(key: newKey);
  }
}

class ViewIdRecord extends AbstractKey<String> {
  ViewIdRecord({required String key}) : super(key: key, tableName: "view_id");
  @override
  copyWithKey({required String newKey}) {
    return ViewIdRecord(key: newKey);
  }
}

class ViewKeyRecord extends AbstractKey<String> {
  ViewKeyRecord({required String key}) : super(key: key, tableName: "view_key");
  @override
  copyWithKey({required String newKey}) {
    return ViewKeyRecord(key: newKey);
  }
}

abstract class KeyValueDatabaseSession {
  commit();
}

abstract class KeyValueDatabase<T extends KeyValueDatabaseSession> {
  late String type;

  Future<void> runInSession(Future<void> Function(T) function);

  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> get(AbstractKey key,
      {T? session});
  Future<List<MapEntry<AbstractKey, Map<String, dynamic>>?>> getMany(
      List<AbstractKey> records,
      {T? session});
  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> last(AbstractKey key,
      {T? session});
  Future<ReadResult> read(
      {AbstractKey? startkey, AbstractKey? endkey, bool? desc, T? session});

  Future<bool> insert(AbstractKey key, {T? session});
  Future<bool> insertMany(AbstractKey keys, {T? session});

  Future<bool> put(AbstractKey key, {T? session});
  Future<bool> putMany(List<AbstractKey> records, {T? session});

  Future<bool> delete(AbstractKey key, {T? session});
  Future<bool> deleteMany(List<AbstractKey> records, {T? session});

  Future<bool> deleteTable(AbstractKey key, T? session);
  Future<bool> deleteDatabase({T? session});
}
