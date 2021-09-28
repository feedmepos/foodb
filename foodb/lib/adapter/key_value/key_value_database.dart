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
  T? key;
  final String tableName;
  AbstractKey({
    this.key,
    required this.tableName,
  });
  AbstractKey copyWithKey({required T newKey});
  int compareTo(other) {
    if (key!=null && other is AbstractKey) {
      return key!.compareTo(other.key);
    }
    return -1;
  }
}

class DocKey extends AbstractKey<String> {
  DocKey({String? key}) : super(key: key, tableName: "doc");
  
  @override
  copyWithKey({required String newKey}) {
    return DocKey(key: newKey);
  }
}

class LocalDocKey extends AbstractKey<String> {
  LocalDocKey({String? key}) : super(key: key, tableName: "local_doc");
  @override
  copyWithKey({required String newKey}) {
    return LocalDocKey(key: newKey);
  }
}

class SequenceKey extends AbstractKey<int> {
  SequenceKey({int? key}) : super(key: key, tableName: "sequence");
  
  @override
  copyWithKey({required int newKey}) {
    return SequenceKey(key: newKey);
  }
}

class ViewMetaKey extends AbstractKey<String> {
  ViewMetaKey({String? key}) : super(key: key, tableName: "view_meta");
  
  @override
  copyWithKey({required String newKey}) {
    return ViewMetaKey(key: newKey);
  }
}

class ViewIdKey extends AbstractKey<String> {
  String view;

  ViewIdKey({String? key, required this.view})
      : super(key: key, tableName: "view_id");
  
  @override
  copyWithKey({required String newKey}) {
    return ViewIdKey(key: newKey, view: this.view);
  }
}

class ViewKeyKey extends AbstractKey<String> {
  String view;

  ViewKeyKey({String? key, required this.view}) : super(key: key, tableName: "view_key");
  @override
  copyWithKey({required String newKey}) {
    return ViewKeyKey(key: newKey, view: this.view);
  }
}

abstract class KeyValueDatabaseSession {
  commit();
}

abstract class KeyValueDatabase<T extends KeyValueDatabaseSession> {
  late String type;

  Future<bool> initDb();

  Future<void> runInSession(Future<void> Function(T) function);

  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> get(AbstractKey key,
      {T? session});
  Future<List<MapEntry<AbstractKey, Map<String, dynamic>>?>> getMany(
      List<AbstractKey> keys,
      {T? session});
  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> last(AbstractKey key,
      {T? session});
  Future<ReadResult> read(AbstractKey keyType,
      {AbstractKey? startkey, AbstractKey? endkey, bool? desc, T? session});

  Future<bool> put(AbstractKey key, Map<String, dynamic> value, {T? session});
  Future<bool> putMany(Map<AbstractKey, Map<String, dynamic>> entries,
      {T? session});

  Future<bool> delete(AbstractKey key, {T? session});
  Future<bool> deleteMany(List<AbstractKey> keys, {T? session});

  Future<int> tableSize(AbstractKey key, {T? session});
  Future<bool> deleteTable(AbstractKey key, {T? session});
  Future<bool> destroy({T? session});
}
