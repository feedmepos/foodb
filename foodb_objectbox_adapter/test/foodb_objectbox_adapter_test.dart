import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_test/foodb_test.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:path/path.dart';

Future<ObjectBoxAdapter> getAdapter(String dbName,
    {bool persist = false}) async {
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
  store = await openStore(directory: directory);
  final adapter = ObjectBoxAdapter(store);
  await adapter.initDb();
  return adapter;
}

class ObjectBoxTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix = 'test-'}) async {
    var name = '$prefix$dbName';
    var db = await getAdapter(name);
    return Foodb.keyvalue(dbName: '$name', keyValueDb: db);
  }
}

void main() {
  test('get-many', () async {
    final adapter = await getAdapter('get-many');
    await adapter.put(DocKey(key: '1'), {});
    await adapter.put(DocKey(key: '2'), {});
    var res = await adapter
        .getMany([DocKey(key: '1'), DocKey(key: '3'), DocKey(key: '2')]);
    print(res);
  });
  test('get-many-int', () async {
    final adapter = await getAdapter('get-many');
    await adapter.put(SequenceKey(key: 1), {});
    await adapter.put(SequenceKey(key: 2), {});
    var res = await adapter.getMany(
        [SequenceKey(key: 1), SequenceKey(key: 3), SequenceKey(key: 2)]);
    print(res);
  });
}
