import 'package:test/test.dart';
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
    expect(TestKey(key: 'b').compareTo(TestKey(key: 'a')), equals(1));
    expect(TestKey(key: 'b').compareTo(TestKey(key: 'b\ufff0')), equals(-1));
    expect(TestKey(key: 'b').compareTo(TestKey(key: 'b')), equals(0));
    expect(TestKey(key: 'b').compareTo(TestKey(key: 'c')), equals(-1));
  });

  test('Can sort encoded view key', () {
    final toSort = [
      ViewKeyMeta(key: ['order', 'PENDING'], docId: 'a', index: 0),
      ViewKeyMeta(key: ['order', 'COMPLETED'], docId: 'a', index: 0),
      ViewKeyMeta(key: ['bill', 'PENDING'], docId: 'a', index: 0),
      ViewKeyMeta(key: ['bill', 'DRAFT'], docId: 'a', index: 0),
      ViewKeyMeta(key: ['item', 'DRAFT'], docId: 'a', index: 0),
      ViewKeyMeta(key: ['item', 'COMPLETED'], docId: 'a', index: 0),
    ];

    final keys = toSort.map((e) => e.encode()).toList();
    keys.sort();
    final result = keys.map((e) => ViewKeyMeta.decode(e)).toList();
    expect(result[0].key, toSort[3].key);
    expect(result[1].key, toSort[2].key);
    expect(result[2].key, toSort[5].key);
    expect(result[3].key, toSort[4].key);
    expect(result[4].key, toSort[1].key);
    expect(result[5].key, toSort[0].key);
  });
}
