library foodb_objectbox_adapter;

import 'dart:convert';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/key_value/key_value_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

const int int64MaxValue = 9223372036854775807;

abstract class BaseObjectType<T> {
  abstract Box box;
  ObjectBoxEntity formObject(T key, Map<String, dynamic> value);
  ObjectBoxEntity? getObjectByKey(key);
  ObjectBoxEntity? getLastObject();
  List<ObjectBoxEntity> readObjectBetween(
      T? startkey, T? endkey, bool? descending);
}

class DocObjectType extends BaseObjectType<String> {
  @override
  late Box box;

  DocObjectType({required Store store}) {
    box = store.box<DocObject>();
  }

  @override
  DocObject formObject(String key, Map<String, dynamic> value) {
    return DocObject(key: key, value: jsonEncode(value));
  }

  @override
  DocObject? getObjectByKey(key) {
    var list = box.query(DocObject_.key.equals(key)).build().find();
    if (list.length > 0) return list[0];
    return null;
  }

  @override
  List<DocObject> readObjectBetween(
      String? startkey, String? endkey, bool? descending) {
    Query query = (box.query(DocObject_.key
            .greaterOrEqual(startkey ?? "")
            .and(DocObject_.key.lessOrEqual(endkey ?? "\uffff")))
          ..order(DocObject_.key,
              flags: (descending == true) ? Order.descending : 0))
        .build();

    return query.find().map<DocObject>((e) => e).toList();
  }

  @override
  DocObject? getLastObject() {
    Query query =
        (box.query()..order(DocObject_.key, flags: Order.descending)).build();
    query.limit = 1;
    var docs = query.find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

class LocalDocObjectType extends BaseObjectType {
  @override
  late Box box;

  LocalDocObjectType({required Store store}) {
    box = store.box<LocalDocObject>();
  }

  @override
  LocalDocObject formObject(String key, Map<String, dynamic> value) {
    return LocalDocObject(key: key, value: jsonEncode(value));
  }

  @override
  LocalDocObject? getObjectByKey(key) {
    var list = box.query(LocalDocObject_.key.equals(key)).build().find();
    if (list.length > 0) return list[0];
    return null;
  }

  @override
  List<LocalDocObject> readObjectBetween(
      String? startkey, String? endkey, bool? descending) {
    Query query = (box.query(LocalDocObject_.key
            .greaterOrEqual(startkey ?? "")
            .and(LocalDocObject_.key.lessOrEqual(endkey ?? "\uffff")))
          ..order(LocalDocObject_.key,
              flags: (descending == true) ? Order.descending : 0))
        .build();

    return query.find().map<LocalDocObject>((e) => e).toList();
  }

  @override
  LocalDocObject? getLastObject() {
    Query query = (box.query()
          ..order(LocalDocObject_.key, flags: Order.descending))
        .build();
    query.limit = 1;
    var docs = query.find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

class SequenceObjectType extends BaseObjectType {
  @override
  late Box box;

  SequenceObjectType({required Store store}) {
    box = store.box<SequenceObject>();
  }

  @override
  SequenceObject formObject(String key, Map<String, dynamic> value) {
    return SequenceObject(
        id: int.parse(key), key: key, value: jsonEncode(value));
  }

  @override
  SequenceObject? getObjectByKey(key) {
    return box.get(int.parse(key));
  }

  @override
  List<SequenceObject> readObjectBetween(
      String? startkey, String? endkey, bool? descending) {
    Query query = (box.query(SequenceObject_.id
            .greaterOrEqual(int.parse(startkey ?? "0"))
            .and(SequenceObject_.id
                .lessOrEqual(int.parse(endkey ?? "$int64MaxValue"))))
          ..order(SequenceObject_.id,
              flags: (descending == true) ? Order.descending : 0))
        .build();

    return query.find().map<SequenceObject>((e) => e).toList();
  }

  @override
  SequenceObject? getLastObject() {
    Query query = (box.query()
          ..order(SequenceObject_.id, flags: Order.descending))
        .build();
    var docs = (query..limit = 1).find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

class ViewMetaObjectType extends BaseObjectType {
  @override
  late Box box;

  ViewMetaObjectType({required Store store}) {
    box = store.box<ViewMetaObject>();
  }

  @override
  ViewMetaObject formObject(String key, Map<String, dynamic> value) {
    return ViewMetaObject(key: key, value: jsonEncode(value));
  }

  @override
  ViewMetaObject? getObjectByKey(key) {
    var list = box.query(ViewMetaObject_.key.equals(key)).build().find();
    if (list.length > 0) return list[0];
    return null;
  }

  @override
  List<ViewMetaObject> readObjectBetween(
      String? startkey, String? endkey, bool? descending) {
    Query query = (box.query(ViewMetaObject_.key
            .greaterOrEqual(startkey ?? "")
            .and(ViewMetaObject_.key.lessOrEqual(endkey ?? "\uffff")))
          ..order(ViewMetaObject_.key,
              flags: (descending == true) ? Order.descending : 0))
        .build();

    return query.find().map<ViewMetaObject>((e) => e).toList();
  }

  @override
  ViewMetaObject? getLastObject() {
    Query query = (box.query()
          ..order(ViewMetaObject_.key, flags: Order.descending))
        .build();
    var docs = (query..limit = 1).find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

class ViewIdObjectType extends BaseObjectType {
  @override
  late Box box;
  String tableName;

  ViewIdObjectType({required Store store, required this.tableName}) {
    box = store.box<ViewIdObject>();
  }

  @override
  ViewIdObject formObject(String key, Map<String, dynamic> value) {
    return ViewIdObject(key: "${tableName}_${key}", value: jsonEncode(value));
  }

  @override
  ViewIdObject? getObjectByKey(key) {
    var list = box
        .query(ViewIdObject_.key.equals("${tableName}_${key}"))
        .build()
        .find();
    if (list.length > 0) return list[0];
    return null;
  }

  @override
  List<ViewIdObject> readObjectBetween(
      String? startkey, String? endkey, bool? descending) {
    Query query = (box.query(ViewIdObject_.key
            .greaterOrEqual("${tableName}_${startkey ?? ""}")
            .and(ViewIdObject_.key
                .lessOrEqual("${tableName}_${endkey ?? "\uffff"}")))
          ..order(ViewIdObject_.key,
              flags: (descending == true) ? Order.descending : 0))
        .build();

    return query.find().map<ViewIdObject>((e) => e).toList();
  }

  @override
  ViewIdObject? getLastObject() {
    Query query = (box.query(ViewIdObject_.key.startsWith(tableName))
          ..order(ViewIdObject_.key, flags: Order.descending))
        .build();
    var docs = (query..limit = 1).find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

class ViewKeyObjectType extends BaseObjectType {
  @override
  late Box box;
  String tableName;

  ViewKeyObjectType({required Store store, required this.tableName}) {
    box = store.box<ViewKeyObject>();
  }

  @override
  ViewKeyObject formObject(String key, Map<String, dynamic> value) {
    return ViewKeyObject(key: "${tableName}_${key}", value: jsonEncode(value));
  }

  @override
  ViewKeyObject? getObjectByKey(key) {
    var list = box
        .query(ViewKeyObject_.key.equals("${tableName}_${key}"))
        .build()
        .find();
    if (list.length > 0) return list[0];
    return null;
  }

  @override
  List<ViewKeyObject> readObjectBetween(
      String? startkey, String? endkey, bool? descending) {
    Query query = (box.query(ViewKeyObject_.key
            .greaterOrEqual("${tableName}_${startkey ?? ""}")
            .and(ViewKeyObject_.key
                .lessOrEqual("${tableName}_${endkey ?? "\uffff"}")))
          ..order(ViewKeyObject_.key,
              flags: (descending == true) ? Order.descending : 0))
        .build();

    return query.find().map<ViewKeyObject>((e) => e).toList();
  }

  @override
  ViewKeyObject? getLastObject() {
    Query query = (box.query(ViewKeyObject_.key.startsWith(tableName))
          ..order(ViewKeyObject_.key, flags: Order.descending))
        .build();
    var docs = (query..limit = 1).find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

class ObjectBox implements KeyValueDatabase {
  static Store? _store;
  List<List<Object?>> batchResult = [];

  Future<BaseObjectType> _getObjectType(AbstractRecord type) async {
    await _iniDatabase();
    switch (type.runtimeType) {
      case DocRecord:
        return DocObjectType(store: _store!);
      case LocalDocRecord:
        return LocalDocObjectType(store: _store!);
      case SequenceRecord:
        return SequenceObjectType(store: _store!);
      case ViewMetaRecord:
        return ViewMetaObjectType(store: _store!);
      case ViewIdRecord:
        return ViewIdObjectType(store: _store!, tableName: type.type);
      case ViewKeyRecord:
        return ViewKeyObjectType(store: _store!, tableName: type.type);
      default:
        throw AdapterException(error: "Invalid DataType");
    }
  }

  Future<void> _iniDatabase() async {
    if (_store == null) {
      _store = await openStore();
    }
  }

  @override
  Future<void> insert(AbstractRecord type,
      {required String key, required Map<String, dynamic> object}) async {
    BaseObjectType objectType = await _getObjectType(type);
    ObjectBoxEntity entity = objectType.formObject(key, object);
    objectType.box.put(entity);
  }

  @override
  Future<void> insertMany(AbstractRecord type,
      {required Map<String, dynamic> objects}) async {
    BaseObjectType objectType = await _getObjectType(type);
    objects.forEach((key, value) {
      ObjectBoxEntity entity = objectType.formObject(key, value);
      objectType.box.put(entity);
    });
  }

  @override
  Future<void> update(AbstractRecord type,
      {required String key, required Map<String, dynamic> object}) async {
    BaseObjectType objectType = await _getObjectType(type);
    ObjectBoxEntity? entity = objectType.getObjectByKey(key);
    entity!.doc = object;
    objectType.box.put(entity);
  }

  @override
  Future<bool> delete(AbstractRecord type, {required String key}) async {
    BaseObjectType objectType = await _getObjectType(type);
    ObjectBoxEntity? entity = objectType.getObjectByKey(key);
    if (entity != null) {
      objectType.box.remove(entity.id);
    }

    return true;
  }

  @override
  Future<bool> deleteMany(AbstractRecord type,
      {required List<String> keys}) async {
    BaseObjectType objectType = await _getObjectType(type);
    List<int> ids = [];
    keys.forEach((key) {
      ObjectBoxEntity? entity = objectType.getObjectByKey(key);
      if (entity != null) {
        ids.add(entity.id);
      }
    });
    objectType.box.removeMany(ids);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> get(AbstractRecord type,
      {required String key}) async {
    BaseObjectType objectType = await _getObjectType(type);
    return objectType.getObjectByKey(key)?.doc;
  }

  @override
  Future<Map<String, dynamic>> getMany(AbstractRecord type,
      {required List<String> keys}) async {
    BaseObjectType objectType = await _getObjectType(type);

    Map<String, dynamic> map = {};

    keys.forEach((key) {
      map.putIfAbsent(key, () => objectType.getObjectByKey(key)?.doc);
    });

    return map;
  }

  @override
  Future<MapEntry<String, dynamic>?> last(AbstractRecord type) async {
    BaseObjectType objectType = await _getObjectType(type);
    ObjectBoxEntity? entity = objectType.getLastObject();

    return entity != null ? MapEntry(entity.key!, entity.doc) : null;
  }

  @override
  Future<bool> put(AbstractRecord type,
      {required String key, required Map<String, dynamic> object}) async {
    BaseObjectType objectType = await _getObjectType(type);
    ObjectBoxEntity? entity = objectType.getObjectByKey(key);
    if (entity != null) {
      entity.doc = object;
    } else {
      entity = objectType.formObject(key, object);
    }
    objectType.box.put(entity);
    return true;
  }

  @override
  Future<bool> putMany(AbstractRecord type,
      {required Map<String, dynamic> objects}) async {
    BaseObjectType objectType = await _getObjectType(type);
    objects.forEach((key, value) {
      ObjectBoxEntity? entity = objectType.getObjectByKey(key);
      if (entity != null) {
        entity.doc = value;
      } else {
        entity = objectType.formObject(key, value);
      }
      objectType.box.put(entity);
    });

    return true;
  }

  //toask : offset no need to implement?
  @override
  Future<ReadResult> read(AbstractRecord type,
      {String? startkey, String? endkey, bool? desc}) async {
    BaseObjectType objectType = await _getObjectType(type);
    List<ObjectBoxEntity> entities =
        objectType.readObjectBetween(startkey, endkey, desc);
    return ReadResult(
        docs:
            Map.fromIterable(entities, key: (e) => e.key, value: (e) => e.doc),
        offset: 0,
        totalRows: await tableSize(type));
  }

  @override
  Future<int> tableSize(AbstractRecord type) async {
    BaseObjectType objectType = await _getObjectType(type);
    return objectType.box.count();
  }

  @override
  Future<bool> deleteTable(AbstractRecord type) async {
    BaseObjectType objectType = await _getObjectType(type);
    objectType.box.removeAll();
    return true;
  }

  @override
  Future<bool> deleteDatabase() async {
    await _iniDatabase();
    await _store!.runInTransaction(TxMode.write, () {
      _store!.box<DocObject>().removeAll();
      _store!.box<LocalDocObject>().removeAll();
      _store!.box<SequenceObject>().removeAll();
      _store!.box<ViewMetaObject>().removeAll();
      _store!.box<ViewKeyObject>().removeAll();
      _store!.box<ViewIdObject>().removeAll();
    });
    return Future.value(true);
  }
}
