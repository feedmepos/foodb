import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_hive_adapter/foodb_hive_adapter.dart';
import 'package:foodb_test/foodb_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' show join;

Future<FoodbHiveAdapter> getAdapter(String dbName,
    {bool persist = false}) async {
  final dir = Directory(join(Directory.current.path, 'temp'));
  if (!persist) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync();
    addTearDown(() async {
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }
  final adapter = FoodbHiveAdapter(dataDir: dir);
  await adapter.initDb();
  return adapter;
}

class HiveTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix = 'test-'}) async {
    var name = '$prefix$dbName';
    var db = await getAdapter(name);
    return Foodb.keyvalue(dbName: name, keyValueDb: db);
  }
}

void main() {
  test('initDb', () async {
    final adapter = await getAdapter('initDb');
    expect(adapter, isNotNull);
  });
  test('single operation', () async {
    final adapter = await getAdapter('single-operation');
    expect(await adapter.tableSize(DocKey()), 0);
    expect(await adapter.put(DocKey(key: 'a'), {'a': 1}), true);
    expect(await adapter.tableSize(DocKey()), 1);
    expect(await adapter.put(DocKey(key: 'a'), {'a': 1}), true);
    expect(await adapter.tableSize(DocKey()), 1);
    var getRes = await adapter.get(DocKey(key: 'a'));
    expect(getRes, isNotNull);
    expect(getRes!.value['a'], 1);
    expect(await adapter.delete(DocKey(key: 'a')), true);
    getRes = await adapter.get(DocKey(key: 'a'));
    expect(getRes, isNull);
    expect(await adapter.tableSize(DocKey()), 0);
    expect(await adapter.delete(DocKey(key: 'a')), true);
  });
  test('bulk operation', () async {
    final adapter = await getAdapter('bulk-operation');
    expect(await adapter.tableSize(DocKey()), 0);
    expect(
        await adapter.putMany({
          DocKey(key: 'a'): {'a': 1},
          DocKey(key: 'b'): {'b': 2},
          DocKey(key: 'c'): {'c': 3}
        }),
        true);
    expect(await adapter.tableSize(DocKey()), 3);
    expect(
        await adapter.putMany({
          DocKey(key: 'a'): {'a': 1},
          DocKey(key: 'b'): {'b': 2},
          DocKey(key: 'c'): {'c': 3}
        }),
        true);
    expect(await adapter.tableSize(DocKey()), 3);
    var getRes = await adapter
        .getMany([DocKey(key: 'a'), DocKey(key: 'b'), DocKey(key: 'c')]);
    expect(getRes, isNotNull);
    expect(getRes.length, 3);
    expect(getRes[DocKey(key: 'a')]!['a'], 1);
    expect(getRes[DocKey(key: 'b')]!['b'], 2);
    expect(getRes[DocKey(key: 'c')]!['c'], 3);
    var lastRes = await adapter.last(DocKey());
    expect(lastRes, isNotNull);
    expect(lastRes!.key.key, 'c');
    var readRes = await adapter.read(DocKey(),
        desc: false, inclusiveStart: false, inclusiveEnd: false);
    expect(readRes.records.length, 3);
    expect(
        await adapter
            .deleteMany([DocKey(key: 'a'), DocKey(key: 'b'), DocKey(key: 'c')]),
        true);
    expect(await adapter.tableSize(DocKey()), 0);
    getRes = await adapter
        .getMany([DocKey(key: 'a'), DocKey(key: 'b'), DocKey(key: 'c')]);
    expect(getRes.values.where((element) => element == null).length, 3);
    readRes = await adapter.read(DocKey(),
        desc: false, inclusiveStart: false, inclusiveEnd: false);
    expect(readRes.records.length, 0);
    expect(
        await adapter
            .deleteMany([DocKey(key: 'a'), DocKey(key: 'b'), DocKey(key: 'c')]),
        true);
  });
  group('read', () {});
}
