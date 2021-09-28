import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/key_value/in_memory_database.dart';
import 'package:foodb/adapter/key_value/key_value_database.dart';

class TestKey extends AbstractKey<String> {
  TestKey({required String key}) : super(key: key, tableName: 'test');

  @override
  AbstractKey<Comparable> copyWithKey({required String newKey}) {
    return TestKey(key: newKey);
  }
}

void main() {
  test('Splaytreemap correct key finding', () {
    final map = SplayTreeMap<TestKey, String>();
    map.putIfAbsent(TestKey(key: 'a'), () => 'a');
    expect(map[TestKey(key: 'a')], isNotNull);
    expect(map[TestKey(key: 'b')], isNull);
  });

  test('read', () async {
    final db = InMemoryDatabase();
    await db.put(DocKey(key: 'a'), {});
    await db.put(DocKey(key: 'b'), {});

    ReadResult result = await db.read(DocKey(key: ''));
    expect(result.records.length, equals(2));
    result = await db.read(DocKey(key: ''), startkey: DocKey(key: 'b'));
    expect(result.records.length, equals(1));
    result = await db.read(DocKey(key: ''), endkey: DocKey(key: 'a'));
    expect(result.records.length, equals(0));
    result = await db.read(DocKey(key: ''), endkey: DocKey(key: 'a\ufff0'));
    expect(result.records.length, equals(1));
  });
}
