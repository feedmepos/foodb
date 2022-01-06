// You have generated a new plugin project without
// specifying the `--platforms` flag. A plugin project supports no platforms is generated.
// To add platforms, run `flutter create -t plugin --platforms <platforms> .` under the same
// directory. You can also find a detailed instruction on how to add platforms in the `pubspec.yaml` at https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'dart:convert';
import 'dart:io';

import 'package:foodb/key_value_adapter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart';
import 'package:quiver/collection.dart';
import 'package:crypto/crypto.dart';

String _hiveTableName({required String designDocId, required String viewId}) {
  return '__v__${md5.convert(utf8.encode('$designDocId$viewId'))}';
}

class FoodbHiveAdapter implements KeyValueAdapter {
  @override
  String type = 'hive';
  Directory dataDir;

  final Map<String, AvlTreeSet<AbstractKey>> _avlTrees = {};
  final Map<String, LazyBox<String>> _boxes = {};

  String Function({required String designDocId, required String viewId})
      getViewTableName = _hiveTableName;
  String get allDocViewName =>
      KeyValueAdapter.getAllDocViewTableName(getViewTableName);

  FoodbHiveAdapter({required this.dataDir});

  Future<String> getBoxName(AbstractKey key) async {
    String tableName = KeyValueAdapter.keyToTableName(key);
    if (!_boxes.keys.contains(tableName)) {
      _boxes[tableName] = await Hive.openLazyBox(tableName);
      _avlTrees[tableName] =
          AvlTreeSet<AbstractKey>(comparator: (a, b) => a.compareTo(b));
    }
    return tableName;
  }

  dynamic encodeKey(AbstractKey? key, {bool isEnd = false}) {
    dynamic result = key?.key;
    if (key is ViewKeyMetaKey) {
      result = key.key?.encode() ?? (isEnd ? '\uffff' : '');
    }
    if (result is String) {
      result = stripReservedCharacter(result);
    }
    return result;
  }

  AbstractKey decodeKey(AbstractKey type, dynamic key) {
    if (key is String) {
      key = revertStripReservedCharacter(key);
    }
    if (type is ViewKeyMetaKey) {
      return type.copyWithKey(newKey: ViewKeyMeta.decode(key));
    }
    return type.copyWithKey(newKey: key);
  }

  @override
  Future<bool> clearTable(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    var boxName = await getBoxName(key);
    await _boxes[boxName]!.clear();
    _avlTrees[boxName]!.clear();
    return true;
  }

  @override
  Future<bool> delete(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    var boxName = await getBoxName(key);
    await _boxes[boxName]!.delete(encodeKey(key));
    _avlTrees[boxName]!.remove(key);
    return true;
  }

  @override
  Future<bool> deleteMany(List<AbstractKey<Comparable>> keys,
      {KeyValueAdapterSession? session}) async {
    if (keys.isNotEmpty) {
      var boxName = await getBoxName(keys[0]);
      await _boxes[boxName]!.deleteAll(keys.map((e) => encodeKey(e)));
      _avlTrees[boxName]!.removeAll(keys);
    }
    return true;
  }

  @override
  Future<bool> destroy({KeyValueAdapterSession? session}) async {
    Hive.deleteFromDisk();
    _avlTrees.clear();
    return true;
  }

  @override
  Future<MapEntry<T2, Map<String, dynamic>>?>
      get<T2 extends AbstractKey<Comparable>>(T2 key,
          {KeyValueAdapterSession? session}) async {
    var boxName = await getBoxName(key);
    var result = await _boxes[boxName]!.get(encodeKey(key));
    if (result != null) {
      return MapEntry(key, jsonDecode(result));
    }
  }

  @override
  Future<Map<T2, Map<String, dynamic>?>>
      getMany<T2 extends AbstractKey<Comparable>>(List<T2> keys,
          {KeyValueAdapterSession? session}) async {
    var result = <T2, Map<String, dynamic>?>{};
    if (keys.isNotEmpty) {
      var boxName = await getBoxName(keys[0]);
      for (var key in keys) {
        var res = await _boxes[boxName]!.get(encodeKey(key));
        result[key] = res != null ? jsonDecode(res) : null;
      }
    }
    return result;
  }

  @override
  Future<bool> initDb() async {
    await Hive.initFlutter(dataDir.path);
    var files = dataDir
        .listSync()
        .whereType<File>()
        .where((element) => element.path.endsWith('.hive'));

    for (var file in files) {
      var name = basename(file.path).replaceAll('.hive', '');
      var box = await Hive.openLazyBox<String>(name);
      var tree = AvlTreeSet<AbstractKey>(
          comparator: (a, b) => a.key!.compareTo(b.key));
      tree.addAll(box.keys
          .map((e) => decodeKey(KeyValueAdapter.tableNameToKey(name), e)));
      _boxes[name] = box;
      _avlTrees[name] = tree;
    }
    return true;
  }

  @override
  Future<MapEntry<T2, Map<String, dynamic>>?>
      last<T2 extends AbstractKey<Comparable>>(T2 key,
          {KeyValueAdapterSession? session}) async {
    var boxName = await getBoxName(key);
    if (_avlTrees[boxName]!.isNotEmpty) {
      var result =
          await _boxes[boxName]!.get(encodeKey(_avlTrees[boxName]!.last));
      if (result != null) {
        return MapEntry(_avlTrees[boxName]!.last as T2, jsonDecode(result));
      }
    }
  }

  @override
  Future<bool> put(AbstractKey<Comparable> key, Map<String, dynamic> value,
      {KeyValueAdapterSession? session}) async {
    var boxName = await getBoxName(key);
    await _boxes[boxName]!.put(encodeKey(key), jsonEncode(value));
    if (!_avlTrees[boxName]!.contains(key)) {
      _avlTrees[boxName]!.add(key);
    }
    return true;
  }

  @override
  Future<bool> putMany(
      Map<AbstractKey<Comparable>, Map<String, dynamic>> entries,
      {KeyValueAdapterSession? session}) async {
    if (entries.isNotEmpty) {
      var boxName = await getBoxName(entries.keys.first);
      await _boxes[boxName]!.putAll(entries
          .map((key, value) => MapEntry(encodeKey(key), jsonEncode(value))));
      _avlTrees[boxName]!.addAll(entries.keys);
    }
    return true;
  }

  @override
  Future<ReadResult<T2>> read<T2 extends AbstractKey<Comparable>>(T2 keyType,
      {T2? startkey,
      T2? endkey,
      KeyValueAdapterSession? session,
      required bool desc,
      required bool inclusiveStart,
      required bool inclusiveEnd,
      int? skip,
      int? limit}) async {
    var boxName = await getBoxName(keyType);
    var tree = _avlTrees[boxName]!;
    var box = _boxes[boxName]!;
    var iterator = desc ? tree.reverseIterator : tree.iterator;
    if (startkey?.key != null) {
      iterator = tree.fromIterator(startkey!,
          reversed: desc, inclusive: inclusiveStart);
    }
    var result = <T2, Map<String, dynamic>>{};
    var keys = tree.map((e) => e).toList();
    while (iterator.moveNext()) {
      if (endkey?.key != null) {
        var matching = (inclusiveEnd ? 1 : 0) * (desc ? -1 : 1);
        var endKeyCmp = iterator.current.compareTo(endkey);
        if (desc && endKeyCmp <= matching) {
          break;
        }
        if (!desc && endKeyCmp >= matching) {
          break;
        }
      }
      if (skip != null && skip > 0) {
        --skip;
      } else {
        var exist = await box.get(encodeKey(iterator.current));
        if (exist != null) {
          result[iterator.current as T2] = jsonDecode(exist);
        }
        if (limit != null) {
          --limit;
        }
      }
      if (limit == 0) {
        break;
      }
    }
    return ReadResult(
        totalRows: await tableSize(keyType), offset: 0, records: result);
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
    return _boxes[await getBoxName(key)]!.length;
  }
}
