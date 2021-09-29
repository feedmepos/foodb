library foodb_objectbox_adapter;

import 'dart:convert';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/key_value/key_value_database.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:objectbox/internal.dart';

const int int64MaxValue = 9223372036854775807;

abstract class ObjectBoxKey<T> {
  QueryProperty get property;
  Condition equals(T key);
  Condition greaterOrEqual(T key);
  Condition lessOrEqual(T key);
}

class ObjectBoxStringKey<T extends ObjectBoxEntity>
    implements ObjectBoxKey<String> {
  QueryStringProperty<T> queryKey;
  get property => queryKey;
  @override
  ObjectBoxStringKey({required this.queryKey});

  Condition<T> equals(String key) {
    return queryKey.equals(key);
  }

  Condition<T> greaterOrEqual(String key) {
    return queryKey.greaterOrEqual(key);
  }

  Condition<T> lessOrEqual(String key) {
    return queryKey.lessOrEqual(key);
  }
}

class ObjectBoxIntKey<T extends ObjectBoxEntity> implements ObjectBoxKey<int> {
  QueryIntegerProperty<T> queryKey;
  get property => queryKey;
  @override
  ObjectBoxIntKey({required this.queryKey});

  Condition<T> equals(int key) {
    return queryKey.equals(key);
  }

  Condition<T> greaterOrEqual(int key) {
    return queryKey.greaterOrEqual(key);
  }

  Condition<T> lessOrEqual(int key) {
    return queryKey.lessOrEqual(key);
  }
}

class ObjectBoxType<T1 extends ObjectBoxEntity, T2> {
  static late Store _store;
  get box => _store.box<T1>();
  ObjectBoxKey keyQuery;
  ObjectBoxType({
    required this.keyQuery,
  });

  ObjectBoxEntity? get(key) {
    var list = box.query(keyQuery.equals(key)).build().find();
    if (list.length > 0) return list[0];
    return null;
  }

  List<ObjectBoxEntity> readBetween(
      {T2? startkey, T2? endkey, bool? descending}) {
    Query query = (box.query(keyQuery
            .greaterOrEqual(startkey ?? "")
            .and(keyQuery.lessOrEqual(endkey ?? "\uffff")))
          ..order(keyQuery.property,
              flags: (descending == true) ? Order.descending : 0))
        .build();
    return query.find().map<T1>((e) => e).toList();
  }

  ObjectBoxEntity? last(key) {
    Query query = (box.query()
          ..order(keyQuery.property, flags: Order.descending))
        .build();
    query.limit = 1;
    var docs = query.find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

final sequenceBox = ObjectBoxType<SequenceEntity, int>(
    keyQuery: ObjectBoxIntKey(queryKey: SequenceEntity_.key));
final docBox = ObjectBoxType<DocEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: DocEntity_.key));
final localDocBox = ObjectBoxType<LocalDocEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: LocalDocEntity_.key));
final viewMetaBox = ObjectBoxType<ViewMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewMetaEntity_.key));
final viewIdBox = ObjectBoxType<ViewIdEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewIdEntity_.key));
final viewKeyBox = ObjectBoxType<ViewKeyEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewKeyEntity_.key));

ObjectBoxType _getBoxFromKey(AbstractKey key) {
  if (key is SequenceKey) {
    return sequenceBox;
  } else if (key is DocKey) {
    return docBox;
  } else if (key is LocalDocKey) {
    return localDocBox;
  } else if (key is ViewMetaKey) {
    return viewMetaBox;
  } else if (key is ViewDocMetaKey) {
    return viewIdBox;
  } else if (key is ViewKeyMetaKey) {
    return viewKeyBox;
  } else {
    throw Exception('invalid key');
  }
}

class ObjectBoxDatabase implements KeyValueDatabase {
  @override
  String type = 'object-box';

  static late Store _store;

  @override
  Future<bool> delete(AbstractKey<Comparable> key,
      {KeyValueDatabaseSession? session}) {
    final boxType = _getBoxFromKey(key);
    boxType.box;
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteMany(List<AbstractKey<Comparable>> keys,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement deleteMany
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteTable(AbstractKey<Comparable> key,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement deleteTable
    throw UnimplementedError();
  }

  @override
  Future<bool> destroy({KeyValueDatabaseSession? session}) {
    // TODO: implement destroy
    throw UnimplementedError();
  }

  @override
  Future<MapEntry<AbstractKey<Comparable>, Map<String, dynamic>>?> get(
      AbstractKey<Comparable> key,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<List<MapEntry<AbstractKey<Comparable>, Map<String, dynamic>>?>>
      getMany(List<AbstractKey<Comparable>> keys,
          {KeyValueDatabaseSession? session}) {
    // TODO: implement getMany
    throw UnimplementedError();
  }

  @override
  Future<bool> initDb() {
    // TODO: implement initDb
    throw UnimplementedError();
  }

  @override
  Future<MapEntry<AbstractKey<Comparable>, Map<String, dynamic>>?> last(
      AbstractKey<Comparable> key,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement last
    throw UnimplementedError();
  }

  @override
  Future<bool> put(AbstractKey<Comparable> key, Map<String, dynamic> value,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<bool> putMany(
      Map<AbstractKey<Comparable>, Map<String, dynamic>> entries,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement putMany
    throw UnimplementedError();
  }

  @override
  Future<ReadResult> read(AbstractKey<Comparable> keyType,
      {AbstractKey<Comparable>? startkey,
      AbstractKey<Comparable>? endkey,
      bool? desc,
      KeyValueDatabaseSession? session}) {
    // TODO: implement read
    throw UnimplementedError();
  }

  @override
  Future<void> runInSession(
      Future<void> Function(KeyValueDatabaseSession p1) function) {
    // TODO: implement runInSession
    throw UnimplementedError();
  }

  @override
  Future<int> tableSize(AbstractKey<Comparable> key,
      {KeyValueDatabaseSession? session}) {
    // TODO: implement tableSize
    throw UnimplementedError();
  }
}
