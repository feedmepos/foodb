library foodb_objectbox_adapter;

import 'dart:convert';

import 'package:foodb/collate.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:objectbox/internal.dart';

const int int64MaxValue = 9223372036854775807;

abstract class ObjectBoxKey<T1 extends ObjectBoxEntity, T2> {
  QueryProperty<T1, T2> get property;
  Condition<T1> equals(T2 key);
  Condition<T1> greaterOrEqual(T2 key);
  Condition<T1> lessOrEqual(T2 key);
  Condition<T1> greaterThan(T2 key);
  Condition<T1> lessThan(T2 key);
}

class ObjectBoxStringKey<T extends ObjectBoxEntity>
    implements ObjectBoxKey<T, String> {
  QueryStringProperty<T> queryKey;
  get property => queryKey;
  @override
  ObjectBoxStringKey({required this.queryKey});

  Condition<T> equals(String key) {
    return queryKey.equals(key);
  }

  Condition<T> greaterThan(String key) {
    return queryKey.greaterThan(key);
  }

  Condition<T> lessThan(String key) {
    return queryKey.lessThan(key);
  }

  Condition<T> greaterOrEqual(String key) {
    return queryKey.greaterOrEqual(key);
  }

  Condition<T> lessOrEqual(String key) {
    return queryKey.lessOrEqual(key);
  }
}

class ObjectBoxIntKey<T extends ObjectBoxEntity>
    implements ObjectBoxKey<T, int> {
  QueryIntegerProperty<T> queryKey;
  get property => queryKey;
  @override
  ObjectBoxIntKey({required this.queryKey});

  Condition<T> equals(int key) {
    return queryKey.equals(key);
  }

  Condition<T> greaterThan(int key) {
    return queryKey.greaterThan(key);
  }

  Condition<T> lessThan(int key) {
    return queryKey.lessThan(key);
  }

  Condition<T> greaterOrEqual(int key) {
    return queryKey.greaterOrEqual(key);
  }

  Condition<T> lessOrEqual(int key) {
    return queryKey.lessOrEqual(key);
  }
}

class ObjectBoxType<T1 extends ObjectBoxEntity, T2> {
  ObjectBoxKey<T1, T2> keyQuery;
  T1 Function() factory;
  Future<bool> Function(Box<T1>, T2)? _removeAll;
  ObjectBoxType({
    required this.keyQuery,
    required this.factory,
    Future<bool> Function(Box<T1>, T2)? removeAll,
  }) : _removeAll = removeAll;

  Box<T1> box(Store store) {
    return store.box<T1>();
  }

  removeAll(Store store, T2 key) {
    return _removeAll?.call(box(store), key) ?? box(store).removeAll();
  }

  put(Store store, T2 key, String val) {
    final exist = get(store, key);
    var obj = factory();
    if (exist != null) obj = exist;
    obj.key = key;
    obj.value = val;
    return box(store).put(obj);
  }

  remove(Store store, key) {
    var all = box(store).getAll();
    var dartHasEqual = all.where((element) {
      return element.key == key;
    });
    final exist = get(store, key);
    return box(store).query(keyQuery.equals(key)).build().remove();
  }

  T1? get(Store store, key) {
    var list = box(store).query(keyQuery.equals(key)).build().find();
    if (list.length > 0) return list[0];
    return null;
  }

  List<T1> readBetween(Store store,
      {T2? startkey,
      T2? endkey,
      required bool descending,
      required bool inclusiveStart,
      required bool inclusiveEnd}) {
    List<Condition<T1>> conditions = [];
    if (startkey != null) {
      if (inclusiveStart) {
        conditions.add(descending == true
            ? keyQuery.lessOrEqual(startkey)
            : keyQuery.greaterOrEqual(startkey));
      } else {
        conditions.add(descending == true
            ? keyQuery.lessThan(startkey)
            : keyQuery.greaterThan(startkey));
      }
    }
    if (endkey != null) {
      if (inclusiveEnd) {
        conditions.add(descending == true
            ? keyQuery.greaterOrEqual(endkey)
            : keyQuery.lessOrEqual(endkey));
      } else {
        conditions.add(descending == true
            ? keyQuery.greaterThan(endkey)
            : keyQuery.lessThan(endkey));
      }
    }

    Condition<T1>? finalContidion;
    if (conditions.isNotEmpty) {
      finalContidion =
          conditions.reduce((value, element) => value.and(element));
    }

    QueryBuilder<T1> query = box(store).query(finalContidion);
    if (descending)
      query.order(keyQuery.property,
          flags: (descending == true) ? Order.descending : 0);

    var result = query.build().find().toList();
    return result;
  }

  ObjectBoxEntity? last(Store store, key) {
    Query query = (box(store).query()
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
    keyQuery: ObjectBoxIntKey(queryKey: SequenceEntity_.key),
    factory: () => SequenceEntity());
final docBox = ObjectBoxType<DocEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: DocEntity_.key),
    factory: () => DocEntity());
final localDocBox = ObjectBoxType<LocalDocEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: LocalDocEntity_.key),
    factory: () => LocalDocEntity());
final viewMetaBox = ObjectBoxType<ViewMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewMetaEntity_.key),
    factory: () => ViewMetaEntity());
final viewDocMetaBox = ObjectBoxType<ViewDocMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewDocMetaEntity_.key),
    factory: () => ViewDocMetaEntity(),
    removeAll: (box, key) async {
      await box.query(ViewDocMetaEntity_.key.startsWith(key)).build().remove();
      return true;
    });
final viewKeyMetaBox = ObjectBoxType<ViewKeyMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewKeyMetaEntity_.key),
    factory: () => ViewKeyMetaEntity(),
    removeAll: (box, key) async {
      await box.query(ViewKeyMetaEntity_.key.startsWith(key)).build().remove();
      return true;
    });
final allDocViewDocMetaBox = ObjectBoxType<AllDocViewDocMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: AllDocViewDocMetaEntity_.key),
    factory: () => AllDocViewDocMetaEntity(),
    removeAll: (box, key) async {
      await box
          .query(AllDocViewDocMetaEntity_.key.startsWith(key))
          .build()
          .remove();
      return true;
    });
final allDocViewKeyMetaBox = ObjectBoxType<AllDocViewKeyMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: AllDocViewKeyMetaEntity_.key),
    factory: () => AllDocViewKeyMetaEntity(),
    removeAll: (box, key) async {
      await box
          .query(AllDocViewKeyMetaEntity_.key.startsWith(key))
          .build()
          .remove();
      return true;
    });

class ObjectBoxAdapter implements KeyValueAdapter {
  @override
  String type = 'object-box';
  Store store;
  ObjectBoxAdapter(this.store);

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
      if (key.viewName == allDocViewName)
        return allDocViewDocMetaBox;
      else
        return viewDocMetaBox;
    } else if (key is ViewKeyMetaKey) {
      if (key.viewName == allDocViewName)
        return allDocViewKeyMetaBox;
      else
        return viewKeyMetaBox;
    } else {
      throw Exception('invalid key');
    }
  }

  dynamic encodeKey(AbstractKey? key) {
    dynamic result = key?.key;
    if (key is AbstractViewKey) {
      final viewName = key.viewName;
      var stringKey = key.key;
      if (key is ViewKeyMetaKey) {
        stringKey = key.key?.encode();
      }
      result = '${viewName}!${stringKey}';
    }
    if (result is String) {
      result = stripReservedCharacter(result);
    }
    return result;
  }

  AbstractKey decodeKey(AbstractKey type, dynamic objectBoxKey) {
    if (objectBoxKey is String) {
      objectBoxKey = revertStripReservedCharacter(objectBoxKey);
    }

    if (type is AbstractViewKey) {
      objectBoxKey as String;
      int index = objectBoxKey.indexOf('!');
      objectBoxKey = objectBoxKey.substring(index + 1);
    }

    if (type is ViewKeyMetaKey) {
      return type.copyWithKey(newKey: ViewKeyMeta.decode(objectBoxKey));
    }
    return type.copyWithKey(newKey: objectBoxKey);
  }

  @override
  Future<bool> delete(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    final boxType = _getBoxFromKey(key);
    final deleteResult = await boxType.remove(store, encodeKey(key));
    return deleteResult == 1 ? true : false;
  }

  @override
  Future<bool> deleteMany(List<AbstractKey<Comparable>> keys,
      {KeyValueAdapterSession? session}) async {
    for (final key in keys) {
      await delete(key);
    }
    return true;
  }

  @override
  Future<bool> deleteTable(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    final boxType = _getBoxFromKey(key);
    await boxType.removeAll(store, encodeKey(key));
    return true;
  }

  @override
  Future<bool> destroy({KeyValueAdapterSession? session}) async {
    List<Box> allDbs = [
      sequenceBox.box(store),
      docBox.box(store),
      localDocBox.box(store),
      viewMetaBox.box(store),
      viewDocMetaBox.box(store),
      viewKeyMetaBox.box(store),
      allDocViewDocMetaBox.box(store),
      allDocViewKeyMetaBox.box(store)
    ];
    await Future.wait(allDbs.map((element) async {
      return element.removeAll();
    }));
    return true;
  }

  @override
  Future<MapEntry<T, Map<String, dynamic>>?> get<T extends AbstractKey>(T key,
      {KeyValueAdapterSession? session}) async {
    final val = await _getBoxFromKey(key).get(store, encodeKey(key));
    if (val == null) return null;
    return MapEntry(key, val.doc);
  }

  @override
  Future<Map<T2, Map<String, dynamic>?>>
      getMany<T2 extends AbstractKey<Comparable>>(List<T2> keys,
          {KeyValueAdapterSession? session}) async {
    Map<T2, Map<String, dynamic>?> result = {};
    for (final r in keys) {
      final value = await get(r, session: session);
      result.putIfAbsent(r, () => value?.value);
    }
    return result;
  }

  @override
  Future<bool> initDb() async {
    return true;
  }

  @override
  Future<MapEntry<T2, Map<String, dynamic>>?>
      last<T2 extends AbstractKey<Comparable>>(T2 key,
          {KeyValueAdapterSession? session}) async {
    final val = await _getBoxFromKey(key).last(store, encodeKey(key));
    if (val == null) return null;
    return MapEntry(decodeKey(key, val.key) as T2, val.doc);
  }

  @override
  Future<bool> put(AbstractKey<Comparable> key, Map<String, dynamic> value,
      {KeyValueAdapterSession? session}) async {
    await _getBoxFromKey(key).put(store, encodeKey(key), jsonEncode(value));
    return true;
  }

  @override
  Future<bool> putMany(
      Map<AbstractKey<Comparable>, Map<String, dynamic>> entries,
      {KeyValueAdapterSession? session}) async {
    Future.wait(entries.entries.map((e) async => put(e.key, e.value)));
    return true;
  }

  @override
  Future<ReadResult<T2>> read<T2 extends AbstractKey<Comparable>>(T2 keyType,
      {T2? startkey,
      T2? endkey,
      required bool desc,
      required bool inclusiveEnd,
      required bool inclusiveStart,
      KeyValueAdapterSession? session}) async {
    final boxType = _getBoxFromKey(keyType);
    final totalRows = boxType.box(store).count();
    final offset = 0;
    final record = await boxType.readBetween(store,
        startkey: encodeKey(startkey),
        endkey: encodeKey(endkey),
        descending: desc,
        inclusiveEnd: inclusiveEnd,
        inclusiveStart: inclusiveStart);

    return ReadResult(
        totalRows: totalRows,
        offset: offset,
        records: record.asMap().map((key, value) =>
            MapEntry(decodeKey(keyType, value.key) as T2, value.doc)));
  }

  @override
  Future<void> runInSession(
      Future<void> Function(KeyValueAdapterSession p1) function) {
    // TODO: implement runInSession
    throw UnimplementedError();
  }

  @override
  Future<int> tableSize(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    return _getBoxFromKey(key).box(store).count();
  }
}
