import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/key_value_adapter.dart';

import 'foodb_objectbox_adapter_test.dart';

void main() {
  testStringKey(AbstractKey key, index) {
    test("string-equality-test for $key", () async {
      final adapter = await getAdapter('string-equality-$index');
      await adapter.put(key, {});
      var result = await adapter.get(key);
      expect(result, isNotNull);
      await adapter.deleteMany([key]);
      result = await adapter.get(key);
      expect(result, isNull);
    });
  }

  final List<AbstractKey> cases = [
    ViewKeyMetaKey(key: ViewKeyMeta(key: '3'), viewName: '')
  ];
  int i = 0;
  for (final c in cases) {
    testStringKey(c, ++i);
  }
}
