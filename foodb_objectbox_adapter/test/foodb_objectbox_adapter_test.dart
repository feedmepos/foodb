import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_test/foodb_test.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:path/path.dart';

Future<ObjectBoxAdapter> getAdapter(String dbName, {bool persist = false}) async {
  var directory = join(Directory.current.path, 'temp/$dbName');
  final dir = Directory(directory);
  late Store store;
  if (!persist) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    addTearDown(() {
      store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }
  if(Store.isOpen(directory)){
    store = Store.attach(getObjectBoxModel(), directory);
  } else {
    store = await openStore(directory: directory);
  }
  final adapter = ObjectBoxAdapter(store);
  await adapter.initDb();
  return adapter;
}

class ObjectBoxTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix = 'test-', autoCompaction = false}) async {
    var name = '$prefix$dbName';
    var db = await getAdapter(name);
    return Foodb.keyvalue(
        dbName: '$name', keyValueDb: db, autoCompaction: autoCompaction);
  }
}

void main() {
  test('get-many', () async {
    final adapter = await getAdapter('get-many');
    await adapter.put(DocKey(key: '1'), {'a': 1});
    await adapter.put(DocKey(key: '2'), {'b': 1});
    var res = await adapter
        .getMany([DocKey(key: '1'), DocKey(key: '3'), DocKey(key: '2')]);
    expect(res, hasLength(3));
    expect(res[DocKey(key: '1')], isNotNull);
    expect(res[DocKey(key: '2')], isNotNull);
    expect(res.containsKey(DocKey(key: '3')), true);
    expect(res[DocKey(key: '3')], isNull);
  });
  test('get-many-int', () async {
    final adapter = await getAdapter('get-many-int');
    await adapter.put(SequenceKey(key: 1), {'a': 1});
    await adapter.put(SequenceKey(key: 2), {'b': 1});
    var res = await adapter.getMany(
        [SequenceKey(key: 1), SequenceKey(key: 3), SequenceKey(key: 2)]);
    expect(res, hasLength(3));
    expect(res[SequenceKey(key: 1)], isNotNull);
    expect(res[SequenceKey(key: 2)], isNotNull);
    expect(res.containsKey(SequenceKey(key: 3)), true);
    expect(res[SequenceKey(key: 3)], isNull);
  });
  test('put-many', () async {
    final adapter = await getAdapter('put-many');
    await adapter.putMany(Map.from({
      DocKey(key: '1'): {'n': 1},
      DocKey(key: '2'): {'n': 1},
    }));
    await adapter.putMany(Map.from({
      DocKey(key: '2'): {'n': 2},
      DocKey(key: '3'): {'n': 1},
    }));
    expect(await adapter.tableSize(DocKey()), 3);
    var res = await adapter
        .getMany([DocKey(key: '1'), DocKey(key: '2'), DocKey(key: '3')]);
    expect(res[DocKey(key: '1')]!['n'], 1);
    expect(res[DocKey(key: '2')]!['n'], 2);
    expect(res[DocKey(key: '3')]!['n'], 1);
  });
}
