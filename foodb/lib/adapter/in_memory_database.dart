import 'dart:async';
import 'dart:collection';

import 'package:foodb/adapter/key_value_adapter.dart';

typedef StoreObject = SplayTreeMap<String, dynamic>;
typedef Stores = Map<String, StoreObject?>;

class InMemoryDatabase implements KeyValueDatabase {
  final Stores _stores = Stores();

  @override
  Future<bool> put(String tableName,
      {required String id, required Map<String, dynamic> object}) async {
    var storeRecords = _stores[tableName];
    // docs db is a List of docs
    // a single doc id can have multiple revisions
    if (_stores[tableName] == null) {
      _stores[tableName] = SplayTreeMap();
    }
    if (_stores[tableName]!.containsKey(id)) {
      _stores[tableName]!.update(id, (value) => object);
    } else {
      _stores[tableName]!.putIfAbsent(id, () => object);
    }
    return true;
  }

  @override
  Future<bool> delete(String tableName, {required String id}) async {
    return _stores[tableName]?.remove(id) ?? false;
  }

  @override
  Future<Map<String, dynamic>?> get(String tableName,
          {required String id}) async =>
      _stores[tableName]?[id];

  @override
  Future<Map<String, Map<String, dynamic>>> read(String tableName,
      {String? startKey, String? endKey, bool? desc}) {
    // TODO: implement read
    throw UnimplementedError();
  }

  @override
  Future<int> tableSize(String tableName) async {
    return _stores[tableName]?.length ?? 0;
  }
}
