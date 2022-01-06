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
    DocKey(
        key:
            '_design/all_docs/_view/all_docs!43_design/type_user_id00'),
    ViewDocMetaKey(key: '2', viewName: 'bb'),
    ViewKeyMetaKey(key: ViewKeyMeta(key: '3'), viewName: 'aa')
  ];
  int i = 0;
  for (final c in cases) {
    testStringKey(c, ++i);
  }

  test("string-range-test", () async {
    final adapter = await getAdapter('string-range');
    await adapter.put(DocKey(key: 'b'), {});
    await adapter.put(DocKey(key: 'c'), {});
    await adapter.put(DocKey(key: 'd'), {});
    var result = await adapter.read(DocKey(),
        startkey: DocKey(key: 'd'),
        endkey: DocKey(key: 'd\ufff0'),
        desc: false,
        inclusiveEnd: true,
        inclusiveStart: true);
    await adapter.read(DocKey(),
        desc: false, inclusiveEnd: true, inclusiveStart: true);
    expect(result.records, isNotEmpty);
  });
}
