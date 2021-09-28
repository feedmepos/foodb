import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  final ctx = CouchdbAdapterTestContext();
  // final ctx = InMemoryAdapterTestContext();
  findTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> findTest() {
  return [
    (AdapterTestContext ctx) {
      test('find()', () async {
        final db = await ctx.db('test-find');
        await db.createIndex(indexFields: ['_id']);
        await db.put(doc: Doc(id: "user_123", model: {}));
        FindResponse<Map<String, dynamic>> findResponse =
            await db.find<Map<String, dynamic>>(
                FindRequest(selector: {
                  '_id': {'\$regex': '^user'}
                }, sort: [
                  {"_id": "asc"}
                ]),
                (json) => json);
        print(findResponse.docs);
        expect(findResponse.docs.length > 0, isTrue);
      });
    },
    (AdapterTestContext ctx) {
      test('explain()', () async {
        final db = await ctx.db('test-explain');
        await db.createIndex(indexFields: ['_id']);
        ExplainResponse explainResponse =
            await db.explain(FindRequest(selector: {
          '_id': {'\$regex': '^user'}
        }, sort: [
          {"_id": "asc"}
        ]));
        print(explainResponse.toJson());
        expect(explainResponse, isNotNull);
      });
    }
  ];
}
