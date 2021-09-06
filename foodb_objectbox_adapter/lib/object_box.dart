// import 'dart:async';
// import 'dart:collection';
// import 'package:foodb/adapter/key_value_adapter.dart';
// import 'package:foodb/common/object_box_entity.dart';
// import 'package:foodb/objectbox.g.dart';
// import 'package:http/retry.dart';

// typedef StoreObject = SplayTreeMap<String, dynamic>;
// typedef Stores = Map<String, StoreObject?>;

// class ObjectBox implements KeyValueDatabase {
//   Store? _store;

//   Future<void> init() async {
//     if (_store == null) {
//       await openStore().then((store) => this._store = store);
//     }
//   }

//   @override
//   Future<bool> put(String tableName,
//       {required String id, required Map<String, dynamic> object}) async {
//     await init();
//     Type t = DocObject;
//     Box box = new Box<t>(_store!);
//     Query<ObjectBoxEntity> query =
//         _box!.query(ObjectBoxEntity_.id.equals(id)).build();
//     List<ObjectBoxEntity> entities = query.find();
//     await _box!.put(ObjectBoxEntity(
//         no: entities.length > 0 ? entities[0].no : 0, id: id, content: object));
//     return true;
//   }

//   @override
//   Future<bool> delete(String tableName, {required String id}) async {
//     _box = await box;
//     Query<ObjectBoxEntity> query =
//         _box!.query(ObjectBoxEntity_.id.equals(id)).build();
//     List<ObjectBoxEntity> entities = query.find();
//     if (entities.length > 0) {
//       await _box!.remove(entities[0].no);
//       return true;
//     }

//     return false;
//   }

//   @override
//   Future<Map<String, dynamic>?> get(String tableName,
//       {required String id}) async {
//     _box = await box;
//     Query<ObjectBoxEntity> query =
//         _box!.query(ObjectBoxEntity_.id.equals(id)).build();
//     List<ObjectBoxEntity> entities = query.find();

//     return entities.length > 0 ? entities[0].doc : null;
//   }

//   @override
//   Future<MapEntry<String, dynamic>?> last(String tableName) async {
//     // return _stores[tableName]?.entries.last;
//     _box = await box;
//     // Query<ObjectBoxEntity> query =
//     //     _box!.query(ObjectBoxEntity_.id.startsWith()).build();
//   }

//   @override
//   Future<ReadResult> read(String tableName,
//       {String? startKey, String? endKey, bool? desc}) async {
//     // var table = _stores[tableName];
//     // Map<String, dynamic> result = {};
//     // int offSet = 0;
//     // bool detectedDoc = false;
//     // if (table != null) {
//     //   if (desc == true) {
//     //     if (startKey == null || endKey == null) {
//     //       List<String> keys = table.keys.toList();
//     //       for (int x = table.length - 1; x >= 0; x--) {
//     //         if ((startKey == null || keys[x].compareTo(startKey) <= 0) &&
//     //             (endKey == null || keys[x].compareTo(endKey) >= 0)) {
//     //           result.putIfAbsent(keys[x], () => table[keys[x]]);
//     //           detectedDoc = true;
//     //         } else {
//     //           if (detectedDoc == false) offSet++;
//     //         }
//     //       }
//     //     }
//     //   } else {
//     //     table.entries.forEach((element) {
//     //       if ((startKey == null || element.key.compareTo(startKey) >= 0) &&
//     //           (endKey == null || element.key.compareTo(endKey) <= 0)) {
//     //         result.putIfAbsent(element.key, () => element.value);
//     //         detectedDoc = true;
//     //       } else if (detectedDoc == false) offSet++;
//     //     });
//     //   }
//     // }
//     // return ReadResult(
//     //     docs: result, offset: offSet, totalRows: await tableSize(tableName));
//     throw UnimplementedError();
//   }

//   @override
//   Future<int> tableSize(String tableName) async {
//     // return _stores[tableName]?.length ?? 0;
//     throw UnimplementedError();
//   }
// }
