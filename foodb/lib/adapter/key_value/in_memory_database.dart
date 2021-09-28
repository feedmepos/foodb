import 'dart:async';
import 'dart:collection';

import 'package:synchronized/synchronized.dart';
import 'package:foodb/adapter/key_value/key_value_database.dart';
import 'package:uuid/uuid.dart';

typedef StoreObject = SplayTreeMap<AbstractKey, Map<String, dynamic>>;
typedef Stores = Map<String, StoreObject?>;

class InMemoryDatabaseSession extends KeyValueDatabaseSession {
  static final _lock = Lock();
  static final Map<String, List<Function>> _activeSession = {};

  final sessionId = Uuid().v1();

  InMemoryDatabaseSession() {
    _activeSession[sessionId] = [];
  }

  addOperation(Function fn) {
    _activeSession[sessionId]!.add(fn);
  }

  @override
  commit() async {
    _lock.synchronized(() async {
      for (final task in _activeSession[sessionId]!) {
        // revert operation
        await task();
      }
    });
  }
}

class InMemoryDatabase implements KeyValueDatabase<InMemoryDatabaseSession> {
  final Stores _stores = Stores();

  @override
  String type = 'in_memory';

  @override
  Future<void> runInSession(
      Future<void> Function(InMemoryDatabaseSession p1) function) {
    return function(InMemoryDatabaseSession());
  }

  @override
  Future<bool> initDb() async {
    return true;
  }

  SplayTreeMap<AbstractKey, Map<String, dynamic>> _getTable(String tableName) {
    var table = _stores[tableName];
    if (table == null) {
      table = _stores[tableName] = SplayTreeMap();
    }
    return table;
  }

  // T? _execOperation<T>(InMemoryDatabaseSession? session, T Function() fn) {
  //   if (session != null) {
  //     session.addOperation(fn);
  //   } else {
  //     return fn();
  //   }
  // }

  @override
  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> get(AbstractKey key,
      {InMemoryDatabaseSession? session}) async {
    var val = _getTable(key.tableName)[key];
    if (val != null) {
      return MapEntry(key, val);
    }
    return null;
  }

  @override
  Future<List<MapEntry<AbstractKey, Map<String, dynamic>>?>> getMany(
      List<AbstractKey> keys,
      {InMemoryDatabaseSession? session}) async {
    List<MapEntry<AbstractKey, Map<String, dynamic>>?> result = [];
    for (final r in keys) {
      result.add(await get(r, session: session));
    }
    return result;
  }

  @override
  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> last(AbstractKey key,
      {InMemoryDatabaseSession? session}) async {
    final lastKey = _getTable(key.tableName).lastKey();
    if (lastKey != null) {
      final lastVal = _getTable(key.tableName)[lastKey]!;
      return MapEntry(lastKey, lastVal);
    }
    return null;
  }

  @override
  Future<ReadResult> read(AbstractKey keyType,
      {AbstractKey? startkey,
      AbstractKey? endkey,
      bool? desc,
      InMemoryDatabaseSession? session}) async {
    var table = _getTable(keyType.tableName);
    Map<AbstractKey, Map<String, dynamic>> result = {};
    int? offSet = null;
    var keys = table.keys.toList();
    if (desc == true) {
      keys = keys.reversed.toList();
    }
    for (int x = 0; x < table.length; x++) {
      if ((startkey == null || keys[x].compareTo(startkey) >= 0) &&
          (endkey == null || keys[x].compareTo(endkey) < 0)) {
        result.putIfAbsent(keys[x], () => table[keys[x]]!);
        offSet ??= x;
      }
    }
    offSet ??= table.length;
    return ReadResult(records: result, offset: offSet, totalRows: table.length);
  }

  @override
  Future<bool> put(AbstractKey key, Map<String, dynamic> value,
      {InMemoryDatabaseSession? session}) async {
    var table = _stores[key.tableName];
    if (table == null) {
      table = _stores[key.tableName] = SplayTreeMap();
    }
    table.update(key, (v) => value, ifAbsent: () => value);
    return true;
  }

  @override
  Future<bool> putMany(Map<AbstractKey, Map<String, dynamic>> entries,
      {InMemoryDatabaseSession? session}) async {
    for (final entry in entries.entries) {
      await put(entry.key, entry.value, session: session);
    }
    return true;
  }

  @override
  Future<bool> delete(AbstractKey key,
      {InMemoryDatabaseSession? session}) async {
    var table = _getTable(key.tableName);
    table.remove(key);
    return true;
  }

  @override
  Future<bool> deleteMany(List<AbstractKey> keys,
      {InMemoryDatabaseSession? session}) async {
    for (final key in keys) {
      await delete(key, session: session);
    }
    return true;
  }

  @override
  Future<bool> deleteTable(AbstractKey key,
      {InMemoryDatabaseSession? session}) async {
    _stores[key.tableName]?.clear();
    return true;
  }

  @override
  Future<bool> destroy({InMemoryDatabaseSession? session}) async {
    for (final table in _stores.values) {
      table?.clear();
    }
    return true;
  }

  @override
  Future<int> tableSize(AbstractKey key,
      {InMemoryDatabaseSession? session}) async {
    return _stores[key.tableName]?.length ?? 0;
  }
}
