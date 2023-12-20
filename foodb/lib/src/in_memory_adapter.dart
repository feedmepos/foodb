import 'dart:async';
import 'dart:collection';

import 'package:foodb/key_value_adapter.dart';
import 'package:uuid/uuid.dart';

typedef StoreObject = SplayTreeMap<AbstractKey, Map<String, dynamic>>;
typedef Stores = Map<String, StoreObject?>;

class InMemoryAdapterSession extends KeyValueAdapterSession {
  static final Map<String, List<Function>> _activeSession = {};

  final sessionId = Uuid().v1();

  InMemoryAdapterSession() {
    _activeSession[sessionId] = [];
  }

  addOperation(Function fn) {
    _activeSession[sessionId]!.add(fn);
  }

  @override
  commit() async {
    for (final task in _activeSession[sessionId]!) {
      // revert operation
      await task();
    }
  }
}

class InMemoryAdapter implements KeyValueAdapter<InMemoryAdapterSession> {
  Duration? latency;
  final Stores _stores = Stores();

  String Function({required String designDocId, required String viewId})
      getViewTableName = KeyValueAdapter.defaultGetViewTableName;

  String get allDocViewName =>
      KeyValueAdapter.getAllDocViewTableName(getViewTableName);

  @override
  String type = 'in_memory';

  InMemoryAdapter({
    this.latency,
  });

  delay() async {
    latency != null ? await Future.delayed(latency!) : null;
  }

  @override
  Future<void> runInSession(
      Future<void> Function(InMemoryAdapterSession p1) function) {
    return function(InMemoryAdapterSession());
  }

  @override
  Future<bool> initDb() async {
    return true;
  }

  SplayTreeMap<AbstractKey, Map<String, dynamic>> _getTable(AbstractKey key) {
    String tableName;
    if (key is ViewKeyMetaKey) {
      tableName = '${key.tableName}_${key.viewName}';
    } else if (key is ViewDocMetaKey) {
      tableName = '${key.tableName}_${key.viewName}';
    } else {
      tableName = key.tableName;
    }
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
  Future<MapEntry<T, Map<String, dynamic>>?> get<T extends AbstractKey>(T key,
      {InMemoryAdapterSession? session}) async {
    var table = _getTable(key);
    var val = table[key];
    if (val != null) {
      return MapEntry(key, val);
    }

    return null;
  }

  @override
  Future<Map<T, Map<String, dynamic>?>> getMany<T extends AbstractKey>(
      List<T> keys,
      {InMemoryAdapterSession? session}) async {
    Map<T, Map<String, dynamic>?> result = {};
    for (final r in keys) {
      final value = await get(r, session: session);
      result.putIfAbsent(r, () => value?.value);
    }
    return result;
  }

  @override
  Future<MapEntry<T, Map<String, dynamic>>?> last<T extends AbstractKey>(T key,
      {InMemoryAdapterSession? session}) async {
    final lastKey = _getTable(key).lastKey();
    if (lastKey != null) {
      final lastVal = _getTable(key)[lastKey]!;
      return MapEntry(lastKey as T, lastVal);
    }

    return null;
  }

  @override
  Future<ReadResult<T>> read<T extends AbstractKey>(T keyType,
      {T? startkey,
      T? endkey,
      required bool desc,
      required bool inclusiveStart,
      required bool inclusiveEnd,
      int? skip,
      int? limit,
      InMemoryAdapterSession? session}) async {
    var table = _getTable(keyType);
    Map<T, Map<String, dynamic>> result = {};
    int? offSet = null;
    var keys = table.keys.toList();
    if (desc) {
      keys = keys.reversed.toList();
    }
    for (int x = 0; x < table.length; x++) {
      var startCmp = 0;
      if (startkey?.key != null) {
        final a = keys[x];
        final b = startkey!;
        startCmp = desc ? b.compareTo(a) : a.compareTo(b);
      }
      var endCmp = -1;
      if (endkey?.key != null) {
        final a = keys[x];
        final b = endkey!;
        endCmp = desc ? b.compareTo(a) : a.compareTo(b);
      }
      if ((inclusiveStart ? startCmp >= 0 : startCmp > 0) &&
          (inclusiveEnd ? endCmp <= 0 : endCmp < 0)) {
        if (skip != null && skip > 0) {
          --skip;
        } else {
          result.putIfAbsent(keys[x] as T, () => table[keys[x]]!);
          offSet ??= x;
        }
      }
      if (limit != null && result.length >= limit) break;
    }
    offSet ??= table.length;

    return ReadResult(records: result, offset: offSet, totalRows: table.length);
  }

  @override
  Future<bool> put(AbstractKey key, Map<String, dynamic> value,
      {InMemoryAdapterSession? session}) async {
    var table = _getTable(key);
    table.update(key, (v) => value, ifAbsent: () => value);

    return true;
  }

  @override
  Future<bool> putMany(Map<AbstractKey, Map<String, dynamic>> entries,
      {InMemoryAdapterSession? session}) async {
    await Future.forEach(entries.entries, (MapEntry entry) async {
      await put(entry.key, entry.value, session: session);
    });
    return true;
  }

  @override
  Future<bool> delete(AbstractKey key,
      {InMemoryAdapterSession? session}) async {
    var table = _getTable(key);
    table.remove(key);

    return true;
  }

  @override
  Future<bool> deleteMany(List<AbstractKey> keys,
      {InMemoryAdapterSession? session}) async {
    for (final key in keys) {
      await delete(key, session: session);
    }
    return true;
  }

  @override
  Future<bool> clearTable(AbstractKey key,
      {InMemoryAdapterSession? session}) async {
    final table = _getTable(key);
    table.clear();
    return true;
  }

  @override
  Future<bool> destroy({InMemoryAdapterSession? session}) async {
    for (final table in _stores.values) {
      table?.clear();
    }

    return true;
  }

  @override
  Future<int> tableSize(AbstractKey key,
      {InMemoryAdapterSession? session}) async {
    return _getTable(key).length;
  }

  @override
  Future<bool> deleteAsync(AbstractKey<Comparable> key,
      {InMemoryAdapterSession? session}) {
    return delete(key, session: session);
  }

  @override
  Future<bool> deleteManyAsync(List<AbstractKey<Comparable>> keys,
      {InMemoryAdapterSession? session}) {
    return deleteMany(keys, session: session);
  }

  @override
  Future<Map<T2, Map<String, dynamic>?>>
      getManyAsync<T2 extends AbstractKey<Comparable>>(List<T2> keys,
          {InMemoryAdapterSession? session}) {
    return getMany(keys, session: session);
  }

  @override
  Future<MapEntry<T2, Map<String, dynamic>>?>
      lastAsync<T2 extends AbstractKey<Comparable>>(T2 key,
          {InMemoryAdapterSession? session}) {
    return last(key, session: session);
  }

  @override
  Future<bool> putAsync(AbstractKey<Comparable> key, Map<String, dynamic> value,
      {InMemoryAdapterSession? session}) {
    return put(key, value, session: session);
  }

  @override
  Future<bool> putManyAsync(
      Map<AbstractKey<Comparable>, Map<String, dynamic>> entries,
      {InMemoryAdapterSession? session}) {
    return putMany(entries, session: session);
  }

  @override
  Future<ReadResult<T2>> readAsync<T2 extends AbstractKey<Comparable>>(
    T2 keyType, {
    T2? startkey,
    T2? endkey,
    InMemoryAdapterSession? session,
    required bool desc,
    required bool inclusiveStart,
    required bool inclusiveEnd,
    int? skip,
    int? limit,
  }) {
    return read(
      keyType,
      startkey: startkey,
      endkey: endkey,
      session: session,
      desc: desc,
      inclusiveStart: inclusiveStart,
      inclusiveEnd: inclusiveEnd,
      skip: skip,
      limit: limit,
    );
  }
}
