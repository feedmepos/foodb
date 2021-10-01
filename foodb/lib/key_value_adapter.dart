class ReadResult<T extends AbstractKey> {
  int totalRows;
  int offset;
  Map<T, Map<String, dynamic>> records;
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
    if (other == null) return 0;
    if (key != null && other is AbstractKey) {
      if (other.key == null) return 0;
      return key!.compareTo(other.key);
    }
    return -1;
  }
}

abstract class AbstractViewKey<T extends Comparable> extends AbstractKey<T> {
  String viewName;
  AbstractViewKey(
      {required String tableName, required T? key, required this.viewName})
      : super(tableName: tableName, key: key);

  @override
  int compareTo(other) {
    if (other is ViewDocMetaKey) {
      final viewCompare = viewName.compareTo(other.viewName);
      if (viewCompare != 0) return viewCompare;
      super.compareTo(other);
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

class ViewDocMetaKey extends AbstractViewKey<String> {

  ViewDocMetaKey({required String key,required String viewName})
      : super(key: key, viewName: viewName,tableName: "view_doc_meta");

  @override
  copyWithKey({required String newKey}) {
    return ViewDocMetaKey(key: newKey, viewName: viewName);
  }
}

class ViewKeyMeta implements Comparable {
  final String key;
  final String docId;
  final int index;
  ViewKeyMeta({required this.key, required this.docId, required this.index});
  int compareTo(other) {
    if (other is ViewKeyMeta) {
      final keyCompare = key.compareTo(other.key);
      if (keyCompare != 0) return keyCompare;
      final docIdCompare = docId.compareTo(other.docId);
      if (docIdCompare != 0) return docIdCompare;
      final indexCompare = index.compareTo(other.index);
      if (indexCompare != 0) return indexCompare;
      return 0;
    }
    return -1;
  }

  factory ViewKeyMeta.decode(String str) {
    final splitted = str.split('_');
    return ViewKeyMeta(
        key: splitted[0], docId: splitted[1], index: int.parse(splitted[2]));
  }

  String encode() {
    return [key, docId, index.toString()].join('_');
  }

  factory ViewKeyMeta.fromJson(Map<String, dynamic> json) {
    return ViewKeyMeta(
        key: json['key'], docId: json['docId'], index: json['index']);
  }
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'docId': docId,
      'index': index,
    };
  }
}

class ViewKeyMetaKey extends AbstractViewKey<ViewKeyMeta> {
  ViewKeyMetaKey({ViewKeyMeta? key, required String viewName})
      : super(key: key, viewName: viewName,tableName: "view_key");

  @override
  copyWithKey({required ViewKeyMeta newKey}) {
    return ViewKeyMetaKey(key: newKey, viewName: viewName);
  }

}

abstract class KeyValueAdapterSession {
  commit();
}

abstract class KeyValueAdapter<T extends KeyValueAdapterSession> {
  late String type;

  Future<bool> initDb();

  Future<void> runInSession(Future<void> Function(T) function);

  Future<MapEntry<T2, Map<String, dynamic>>?> get<T2 extends AbstractKey>(
      T2 key,
      {T? session});

  Future<Map<T2, Map<String, dynamic>?>> getMany<T2 extends AbstractKey>(
      List<T2> keys,
      {T? session});

  Future<MapEntry<T2, Map<String, dynamic>>?> last<T2 extends AbstractKey>(
      T2 key,
      {T? session});

  Future<ReadResult<T2>> read<T2 extends AbstractKey>(T2 keyType,
      {T2? startkey, T2? endkey, bool? desc, T? session});

  Future<bool> put(AbstractKey key, Map<String, dynamic> value, {T? session});
  Future<bool> putMany(Map<AbstractKey, Map<String, dynamic>> entries,
      {T? session});

  Future<bool> delete(AbstractKey key, {T? session});
  Future<bool> deleteMany(List<AbstractKey> keys, {T? session});

  Future<int> tableSize(AbstractKey key, {T? session});
  Future<bool> deleteTable(AbstractKey key, {T? session});
  Future<bool> destroy({T? session});
}
