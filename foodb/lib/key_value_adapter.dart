import 'dart:convert';

import 'package:foodb/collate.dart';

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
    if (other == null) return 1;
    if (other is AbstractKey) {
      if (key == null && other.key == null) return 0;
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

class ViewDocMetaKey extends AbstractKey<String> {
  String viewName;
  ViewDocMetaKey({required String key, required this.viewName})
      : super(key: key, tableName: "view_doc_meta");

  @override
  copyWithKey({required String newKey}) {
    return ViewDocMetaKey(key: newKey, viewName: viewName);
  }

  @override
  int compareTo(other) {
    if (other is ViewDocMetaKey) {
      final viewCompare = viewName.compareTo(other.viewName);
      if (viewCompare != 0) return viewCompare;
      return super.compareTo(other);
    }
    return -1;
  }
}

class ViewKeyMeta<T> implements Comparable {
  final T key;
  final String? docId;
  final int? index;
  ViewKeyMeta({required this.key, this.docId, this.index});
  int compareTo(other) {
    if (other is ViewKeyMeta) {
      return this.encode().compareTo(other.encode());
    }
    return -1;
  }

  factory ViewKeyMeta.decode(String str) {
    final decoded = decodeFromIndex(str);
    return ViewKeyMeta(key: decoded[0], docId: decoded[1], index: decoded[2]);
  }

  String encode() {
    return encodeToIndex([key, docId, index]);
  }
}

ListOfViewKeyMetaFromJsonString(String str) {
  List<dynamic> list = jsonDecode(str);
  return list.map((e) => ViewKeyMeta.decode(e)).toList();
}

ListOfViewKeyMetaToJsonString(List<ViewKeyMeta> instances) {
  return jsonEncode(instances.map((e) => e.encode()).toList());
}

class ViewKeyMetaKey extends AbstractKey<ViewKeyMeta> {
  final String viewName;
  ViewKeyMetaKey({ViewKeyMeta? key, required this.viewName})
      : super(key: key, tableName: "view_key");
  @override
  copyWithKey({required ViewKeyMeta newKey}) {
    return ViewKeyMetaKey(key: newKey, viewName: viewName);
  }

  @override
  int compareTo(other) {
    if (other is ViewKeyMetaKey) {
      final viewCompare = viewName.compareTo(other.viewName);
      if (viewCompare != 0) return viewCompare;
    }
    return super.compareTo(other);
  }
}

class ViewValue {
  final dynamic value;
  ViewValue(this.value);
  Map<String, dynamic> toJson() {
    return {
      'v': value,
    };
  }

  factory ViewValue.fromJson(Map<String, dynamic> map) {
    return ViewValue(
      map['v'],
    );
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
      {T2? startkey,
      T2? endkey,
      T? session,
      required bool desc,
      required bool inclusiveStart,
      required bool inclusiveEnd});

  Future<bool> put(AbstractKey key, Map<String, dynamic> value, {T? session});
  Future<bool> putMany(Map<AbstractKey, Map<String, dynamic>> entries,
      {T? session});

  Future<bool> delete(AbstractKey key, {T? session});
  Future<bool> deleteMany(List<AbstractKey> keys, {T? session});

  Future<int> tableSize(AbstractKey key, {T? session});
  Future<bool> deleteTable(AbstractKey key, {T? session});
  Future<bool> destroy({T? session});
}
