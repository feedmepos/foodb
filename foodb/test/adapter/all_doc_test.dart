import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  final ctx = CouchdbAdapterTestContext();
  // final ctx = InMemoryAdapterTestContext();
  allDocTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> allDocTest() {
  return [
    (AdapterTestContext ctx) {
      test("all docs", () async {
        final db = await ctx.db('test-all-docs');
        await db.put(doc: Doc(id: '1', model: {}));
        await db.put(doc: Doc(id: '2', model: {}));
        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        expect(result.totalRows, 2);
        expect(result.rows, hasLength(2));
      });
    },
  ];
}
