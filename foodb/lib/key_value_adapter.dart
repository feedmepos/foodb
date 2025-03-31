import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:foodb/foodb.dart';

import 'package:foodb/src/key_value/collate.dart';
import 'package:foodb/src/in_memory_adapter.dart';

export 'package:foodb/src/key_value/collate.dart';
export 'package:foodb/src/key_value/common.dart';

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

  @override
  int get hashCode => Object.hash(key.hashCode, tableName.hashCode);

  @override
  bool operator ==(o) =>
      o is AbstractKey &&
      tableName == o.tableName &&
      key != null &&
      key!.compareTo(o.key) == 0;
}

abstract class AbstractViewKey<T extends Comparable> extends AbstractKey<T> {
  String viewName;
  AbstractViewKey(
      {required String tableName, required T? key, required this.viewName})
      : super(tableName: tableName, key: key);

  @override
  int compareTo(other) {
    if (other is AbstractViewKey) {
      final viewCompare = viewName.compareTo(other.viewName);
      if (viewCompare != 0) return viewCompare;
      return super.compareTo(other);
    }
    return -1;
  }

  @override
  int get hashCode =>
      Object.hash(viewName.hashCode, key.hashCode, tableName.hashCode);

  @override
  bool operator ==(o) =>
      o is AbstractViewKey && super == o && viewName == o.viewName;
}

class UtilsKey extends AbstractKey<String> {
  UtilsKey({String? key}) : super(key: key, tableName: "utils");

  @override
  copyWithKey({required String newKey}) {
    return UtilsKey(key: newKey);
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
  ViewDocMetaKey({String? key, required String viewName})
      : super(viewName: viewName, key: key, tableName: "view_doc_meta");

  @override
  copyWithKey({required String newKey}) {
    return ViewDocMetaKey(key: newKey, viewName: viewName);
  }
}

class ViewKeyMeta<T> implements Comparable {
  final T key;

  ViewKeyMeta({required this.key});
  int compareTo(other) {
    if (other is ViewKeyMeta) {
      return this.encode().compareTo(other.encode());
    }
    return -1;
  }

  factory ViewKeyMeta.decode(String str) {
    return ViewKeyMeta(key: decodeFromIndex(str));
  }

  String encode() {
    return encodeToIndex(key);
  }

  @override
  int get hashCode => this.encode().hashCode;

  @override
  bool operator ==(o) => o is ViewKeyMeta && this.encode() == o.encode();
}

ListOfViewKeyMetaFromJsonString(String str) {
  List<dynamic> list = jsonDecode(str);
  return list.map((e) => ViewKeyMeta.decode(e)).toList();
}

ListOfViewKeyMetaToJsonString(List<ViewKeyMeta> instances) {
  return jsonEncode(instances.map((e) => e.encode()).toList());
}

class ViewKeyMetaKey extends AbstractViewKey<ViewKeyMeta> {
  ViewKeyMetaKey({ViewKeyMeta? key, required String viewName})
      : super(viewName: viewName, key: key, tableName: "view_key");
  @override
  copyWithKey({required ViewKeyMeta newKey}) {
    return ViewKeyMetaKey(key: newKey, viewName: viewName);
  }
}

class ViewValue {
  List<ViewValueDoc> docs;
  ViewValue({required this.docs});
  Map<String, dynamic> toJson() {
    return {
      'l': docs.map((e) => e.toJson()).toList(),
    };
  }

  factory ViewValue.fromJson(Map<String, dynamic> map) {
    return ViewValue(
        docs: (map['l'] as List<dynamic>)
            .map((e) => ViewValueDoc.fromJson(e))
            .toList());
  }
}

class ViewValueDoc {
  final String docId;
  final dynamic value;
  ViewValueDoc({required this.docId, this.value});
  Map<String, dynamic> toJson() {
    return {
      'd': docId,
      'v': value,
    };
  }

  factory ViewValueDoc.fromJson(Map<String, dynamic> map) {
    return ViewValueDoc(docId: map['d'], value: map['v']);
  }
}

abstract class KeyValueAdapterSession {
  commit();
}

abstract class KeyValueAdapter<T extends KeyValueAdapterSession> {
  late String type;

  static inMemory({Duration? latency}) {
    return InMemoryAdapter(latency: latency);
  }

  static String defaultGetViewTableName(
      {required String designDocId, required String viewId}) {
    return 'd-${designDocId}-v-${viewId}';
    // return 'v-${crypto.md5.convert(utf8.encode(designDocId + viewId))}';
  }

  static String getAllDocViewTableName(
          String Function({required String designDocId, required String viewId})
              getViewNameFn) =>
      getViewNameFn(
          designDocId: allDocDesignDoc.id,
          viewId: allDocDesignDoc.model.views.keys.first);

  String Function({required String designDocId, required String viewId})
      getViewTableName = KeyValueAdapter.defaultGetViewTableName;

  // used as table name, can be override according key value adapter syntax
  String get allDocViewName =>
      KeyValueAdapter.getAllDocViewTableName(getViewTableName);

  static String keyToTableName(AbstractKey key) {
    String tableName = key.tableName;
    if (key is ViewDocMetaKey) {
      tableName += '!${key.viewName}';
    } else if (key is ViewKeyMetaKey) {
      tableName += '!${key.viewName}';
    }
    return tableName;
  }

  static AbstractKey tableNameToKey(String tableName) {
    var key = <AbstractKey>[
      UtilsKey(),
      DocKey(),
      LocalDocKey(),
      SequenceKey(),
      ViewMetaKey(),
      ViewDocMetaKey(viewName: ''),
      ViewKeyMetaKey(viewName: '')
    ].firstWhereOrNull((key) => tableName.startsWith(key.tableName));
    if (key != null) {
      if (key is ViewDocMetaKey) {
        key = ViewDocMetaKey(viewName: tableName.split('!')[1]);
      }
      if (key is ViewKeyMetaKey) {
        key = ViewKeyMetaKey(viewName: tableName.split('!')[1]);
      }
      return key;
    }
    throw Exception('Invalid key for table');
  }

  Future<bool> initDb();

  void runInSession(void Function(T) function);

  MapEntry<T2, Map<String, dynamic>>? get<T2 extends AbstractKey>(T2 key,
      {T? session});

  Map<T2, Map<String, dynamic>?> getMany<T2 extends AbstractKey>(List<T2> keys,
      {T? session});

  MapEntry<T2, Map<String, dynamic>>? last<T2 extends AbstractKey>(T2 key,
      {T? session});

  ReadResult<T2> read<T2 extends AbstractKey>(
    T2 keyType, {
    T2? startkey,
    T2? endkey,
    T? session,
    required bool desc,
    required bool inclusiveStart,
    required bool inclusiveEnd,
    int? skip,
    int? limit,
  });

  bool put(AbstractKey key, Map<String, dynamic> value, {T? session});
  bool putMany(Map<AbstractKey, Map<String, dynamic>> entries, {T? session});

  bool delete(AbstractKey key, {T? session});
  bool deleteMany(List<AbstractKey> keys, {T? session});

  int tableSize(AbstractKey key, {T? session});
  bool clearTable(AbstractKey key, {T? session});
  bool destroy({T? session});
}
