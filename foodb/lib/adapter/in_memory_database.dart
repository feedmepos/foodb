import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:foodb/adapter/key_value_adapter.dart';

typedef StoreObject = SplayTreeMap<String, dynamic>;
typedef SequenceObject = SplayTreeMap<int, dynamic>;
typedef Stores = Map<String, StoreObject?>;
typedef Sequences = Map<String, SequenceObject?>;

class InMemoryDatabaseSession extends KeyValueDatabaseSession {
  @override
  var batch;

  InMemoryDatabaseSession({required this.batch});
}

class InMemoryDatabase implements KeyValueDatabase {
  final Stores _stores = Stores();
  final Sequences _sequences = Sequences();
  List<List<Object?>> batchResult = [];

  @override
  Future<bool> put(String tableName,
      {required key,
      required Map<String, dynamic> object,
      KeyValueDatabaseSession? session}) async {
    if (key.runtimeType == String) {
      if (_stores[tableName] == null) {
        _stores[tableName] = SplayTreeMap();
      }
      _stores[tableName]!
          .update(key, (value) => object, ifAbsent: () => object);
    } else {
      if (_sequences[tableName] == null) {
        _sequences[tableName] = SplayTreeMap();
      }
      _sequences[tableName]!
          .update(key, (value) => object, ifAbsent: () => object);
    }
    if (session != null) {
      batchResult[session.batch].add(key);
    }
    return true;
  }

  @override
  Future<bool> delete(String tableName,
      {required key, KeyValueDatabaseSession? session}) async {
    key.runtimeType == String
        ? _stores[tableName]?.remove(key)
        : _sequences[tableName]?.remove(key);

    if (session != null) {
      batchResult[session.batch].add(key);
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>?> get(String tableName, {required key}) async {
    if (key.runtimeType == String) return _stores[tableName]?[key];
    return _sequences[tableName]?[key];
  }

  @override
  Future<MapEntry<String, dynamic>?> last(String tableName) async {
    return _stores[tableName]?.entries.last;
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
      required KeyValueDatabaseSession session}) async {
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
      required KeyValueDatabaseSession session}) async {
    key.runtimeType == String
        ? _stores[tableName]![key] = object
        : _sequences[tableName]![key] = object;

    batchResult[session.batch].add(key);
  }

  @override
  Future<List<Object?>> runInSession(
      Function(KeyValueDatabaseSession session) runSession) async {
    batchResult.add([]);
    InMemoryDatabaseSession session =
        new InMemoryDatabaseSession(batch: batchResult.length - 1);
    await runSession(session);
    return batchResult[session.batch];
  }
}
