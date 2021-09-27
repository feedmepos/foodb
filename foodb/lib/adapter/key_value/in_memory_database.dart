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
    var val = _stores[key.tableName]![key.key];
    if (val) {
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
  Future<MapEntry<AbstractKey, Map<String, dynamic>>?> last(
      AbstractKey key) async {
    var table = _getTable(key);
    final lastKey = table.lastKey();
    if (lastKey != null) {
      final lastVal = _sequencesTable[lastKey]!;
      return MapEntry(key.copyWithKey(newKey: lastKey), lastVal);
    }
    return null;
  }

  @override
  Future<MapEntry<int, dynamic>?> lastSequence(String tableName) async {
    return _sequences[tableName]?.entries.last;
  }

  @override
  Future<ReadResult> read(String tableName,
      {String? startkey, String? endkey, bool? desc}) async {
    var table = _stores[tableName];
    Map<String, dynamic> result = {};
    int offSet = 0;
    bool detectedDoc = false;
    if (table != null) {
      if (desc == true) {
        if (startkey == null || endkey == null) {
          List<String> keys = table.keys.toList();
          for (int x = table.length - 1; x >= 0; x--) {
            if ((startkey == null || keys[x].compareTo(startkey) <= 0) &&
                (endkey == null || keys[x].compareTo(endkey) >= 0)) {
              result.putIfAbsent(keys[x], () => table[keys[x]]);
              detectedDoc = true;
            } else {
              if (detectedDoc == false) offSet++;
            }
          }
        }
      } else {
        table.entries.forEach((element) {
          if ((startkey == null || element.key.compareTo(startkey) >= 0) &&
              (endkey == null || element.key.compareTo(endkey) <= 0)) {
            result.putIfAbsent(element.key, () => element.value);
            detectedDoc = true;
          } else if (detectedDoc == false) offSet++;
        });
      }
    }

    return ReadResult(
        docs: result, offset: offSet, totalRows: await tableSize(tableName));
  }

  @override
  Future<bool> put(AbstractKey key, {InMemoryDatabaseSession? session}) async {
    if (key is SequenceRecord) {
      _sequencesTable.update(key.key, (value) => key.value!,
          ifAbsent: () => key.value!);
    } else {
      if (_stores[key.tableName] == null) {
        _stores[key.tableName] = SplayTreeMap();
      }
      _stores[key.tableName]!
          .update(key.key, (value) => key.value, ifAbsent: () => key.value);
    }
    return true;
  }

  @override
  Future<bool> putMany(List<AbstractKey> keys,
      {InMemoryDatabaseSession? session}) async {
    for (final key in keys) {
      await put(key, session: session);
    }
    return true;
  }

  @override
  Future<bool> delete(AbstractKey key,
      {InMemoryDatabaseSession? session}) async {
    if (key is SequenceRecord) {
      _sequencesTable.remove(key.key);
    } else {
      _stores[key.tableName]?.remove(key.key);
    }
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
  Future<bool> deleteTable(
      AbstractKey key, InMemoryDatabaseSession? session) async {
    if (key is SequenceRecord) {
      _sequencesTable.clear();
    } else {
      _stores[key.tableName]?.clear();
    }
    return true;
  }

  @override
  Future<bool> deleteDatabase({InMemoryDatabaseSession? session}) async {
    _sequencesTable.clear();
    for (final table in _stores.values) {
      table?.clear();
    }
    return true;
  }

  @override
  Future<Map<int, dynamic>> readSequence(String tableName,
      {int? startkey, int? endkey, bool? desc}) async {
    var table = _sequences[tableName];
    Map<int, dynamic> result = {};
    int offSet = 0;
    bool detectedDoc = false;
    if (table != null) {
      if (desc == true) {
        if (startkey == null || endkey == null) {
          List<int> keys = table.keys.toList();
          for (int x = table.length - 1; x >= 0; x--) {
            if ((startkey == null || keys[x].compareTo(startkey) <= 0) &&
                (endkey == null || keys[x].compareTo(endkey) >= 0)) {
              result.putIfAbsent(keys[x], () => table[keys[x]]);
              detectedDoc = true;
            } else {
              if (detectedDoc == false) offSet++;
            }
          }
        }
      } else {
        table.entries.forEach((element) {
          if ((startkey == null || element.key.compareTo(startkey) >= 0) &&
              (endkey == null || element.key.compareTo(endkey) <= 0)) {
            result.putIfAbsent(element.key, () => element.value);
            detectedDoc = true;
          } else if (detectedDoc == false) offSet++;
        });
      }
    }
    return result;
  }

  @override
  Future<int> tableSize(String tableName) async {
    return _stores[tableName]?.length ?? 0;
  }

  @override
  Future<void> batchInsert(String tableName,
      {required key,
      required Map<String, dynamic> object,
      required InMemoryDatabaseSession session}) async {
    if (key.runtimeType == String) {
      if (_stores[tableName] == null) {
        _stores[tableName] = SplayTreeMap();
      }
      _stores[tableName]!.putIfAbsent(key, () => object);
    } else {
      if (_sequences[tableName] == null) {
        _sequences[tableName] = SplayTreeMap();
      }
      _sequences[tableName]!.putIfAbsent(key, () => object);
    }
    batchResult[session.batch].add(key);
  }

  @override
  Future<void> batchUpdate(String tableName,
      {required key,
      required Map<String, dynamic> object,
      required InMemoryDatabaseSession session}) async {
    key.runtimeType == String
        ? _stores[tableName]![key] = object
        : _sequences[tableName]![key] = object;

    batchResult[session.batch].add(key);
  }

  @override
  Future<List<Object?>> runInSession(
      Function(InMemoryDatabaseSession session) runSession) async {
    batchResult.add([]);
    InMemoryDatabaseSession session =
        new InMemoryDatabaseSession(batch: batchResult.length - 1);
    await runSession(session);
    return batchResult[session.batch];
  }

  @override
  String type;

  @override
  Future<bool> deleteDatabase({InMemoryDatabaseSession? session}) {
    // TODO: implement deleteDatabase
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteMany(AbstractKey type,
      {required List<String> keys, InMemoryDatabaseSession? session}) {
    // TODO: implement deleteMany
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteTable(AbstractKey type, InMemoryDatabaseSession? session) {
    // TODO: implement deleteTable
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getMany(AbstractKey type,
      {required List<String> keys, InMemoryDatabaseSession? session}) {
    // TODO: implement getMany
    throw UnimplementedError();
  }

  @override
  Future<void> insert(AbstractKey type,
      {required String key,
      required Map<String, dynamic> object,
      InMemoryDatabaseSession? session}) {
    // TODO: implement insert
    throw UnimplementedError();
  }

  @override
  Future<void> insertMany(AbstractKey type,
      {required Map<String, dynamic> objects,
      InMemoryDatabaseSession? session}) {
    // TODO: implement insertMany
    throw UnimplementedError();
  }

  @override
  Future<bool> putMany(AbstractKey type,
      {required Map<String, dynamic> objects,
      InMemoryDatabaseSession? session}) {
    // TODO: implement putMany
    throw UnimplementedError();
  }

  @override
  Future<void> update(AbstractKey type,
      {required String key,
      required Map<String, dynamic> object,
      InMemoryDatabaseSession? session}) {
    // TODO: implement update
    throw UnimplementedError();
  }
}
