import 'package:flutter_test/flutter_test.dart';
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
}
