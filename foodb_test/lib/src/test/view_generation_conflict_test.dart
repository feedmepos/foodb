@Timeout(Duration(seconds: 1000))
import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';
import 'package:foodb/foodb.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext(latency: Duration(seconds: 1));
  allDocTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> allDocTest() {
  return [
    (FoodbTestContext ctx) {
      test('allDocs include docs', () async {
        final db = await ctx.db('all-docs-include-docs');
        var doc = await db.put(doc: Doc(id: '1', model: {}));
        var req1 = db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        await db.delete(id: '1', rev: doc.rev);
        var req2 = db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        try {
          await req1;
        } catch (ex) {}
        await req2;
        await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
      });
    },
  ];
}
