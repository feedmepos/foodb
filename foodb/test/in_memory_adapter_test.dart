import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';

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
    final db = InMemoryAdapter();
    await db.put(DocKey(key: 'a'), {});
    await db.put(DocKey(key: 'b'), {});

    ReadResult result = await db.read(DocKey(key: ''),
        desc: false, inclusiveStart: true, inclusiveEnd: true);
    expect(result.records.length, equals(2));
    result = await db.read(DocKey(key: ''),
        startkey: DocKey(key: 'b'),
        desc: false,
        inclusiveStart: true,
        inclusiveEnd: true);
    expect(result.records.length, equals(1));
    result = await db.read(DocKey(key: ''),
        endkey: DocKey(key: 'a'),
        desc: false,
        inclusiveStart: true,
        inclusiveEnd: true);
    expect(result.records.length, equals(0));
    result = await db.read(DocKey(key: ''),
        endkey: DocKey(key: 'a\ufff0'),
        desc: false,
        inclusiveStart: true,
        inclusiveEnd: true);
    expect(result.records.length, equals(1));
  });
}
