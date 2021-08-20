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
    if (_stores[tableName] == null) {
      _stores[tableName] = SplayTreeMap();
    }
    _stores[tableName]!.update(id, (value) => object, ifAbsent: () => object);
    return true;
  }

  @override
  Future<bool> delete(String tableName, {required String id}) async {
    _stores[tableName]?.remove(id);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> get(String tableName,
      {required String id}) async {
    return _stores[tableName]?[id];
  }

  @override
  Future<MapEntry<String, dynamic>?> last(String tableName) async {
    return _stores[tableName]?.entries.last;
  }

  @override
  Future<ReadResult> read(String tableName,
      {String? startKey, String? endKey, bool? desc}) async {
    var table = _stores[tableName];
    Map<String, dynamic> result = {};
    int offSet = 0;
    bool detectedDoc = false;
    if (table != null) {
      if (desc == true) {
        if (startKey == null || endKey == null) {
          List<String> keys = table.keys.toList();
          for (int x = table.length - 1; x >= 0; x--) {
            if ((startKey == null || keys[x].compareTo(startKey) <= 0) &&
                (endKey == null || keys[x].compareTo(endKey) >= 0)) {
              result.putIfAbsent(keys[x], () => table[keys[x]]);
              detectedDoc = true;
            } else {
              if (detectedDoc == false) offSet++;
            }
          }
        }
      } else {
        table.entries.forEach((element) {
          if ((startKey == null || element.key.compareTo(startKey) >= 0) &&
              (endKey == null || element.key.compareTo(endKey) <= 0)) {
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
  Future<int> tableSize(String tableName) async {
    return _stores[tableName]?.length ?? 0;
  }
}
