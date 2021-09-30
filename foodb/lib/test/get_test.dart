import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import '../foodb_test.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext();
  getTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> getTest() {
  return [
    (FoodbTestContext ctx) {
      test('get()', () async {
        final db = await ctx.db('test-put-get');
        PutResponse putResponse =
            await db.put(doc: Doc(id: "test-get", model: {}));
        expect(putResponse.ok, isTrue);

        Doc? doc1 = await db.get(id: 'test-get', fromJsonT: (v) => {});
        expect(doc1, isNotNull);

        Doc? doc2 = await db.get(id: 'test-get-empty', fromJsonT: (v) => {});
        expect(doc2, isNull);
      });
    },
    (FoodbTestContext ctx) {
      test("bulkget with doc and error ", () async {
        final db = await ctx.db('test-bulkget');
        await db.put(
            doc: Doc(
                id: "test-bulkget-conflict",
                model: {},
                rev: Rev.fromString("1-a")),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "test-bulkget-conflict",
                model: {},
                rev: Rev.fromString("1-aa")),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "test-bulkget-with-child",
                model: {},
                rev: Rev.fromString("1-b")),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "test-bulkget-with-child",
                model: {},
                rev: Rev.fromString("2-b"),
                revisions: Revisions(ids: ["b", "b"], start: 2)),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "test-bulkget-missing-child",
                model: {},
                rev: Rev.fromString("1-c")),
            newEdits: false);
        await db.put(doc: Doc(id: "test-bulkget-no-rev", model: {}));

        final response = await db.bulkGet<Map<String, dynamic>>(
            body: BulkGetRequest(docs: [
              BulkGetRequestDoc(
                  id: "test-bulkget-conflict", rev: Rev.fromString("1-aa")),
              BulkGetRequestDoc(
                  id: "test-bulkget-conflict", rev: Rev.fromString("1-a")),
              BulkGetRequestDoc(
                  id: "test-bulkget-with-child", rev: Rev.fromString("2-b")),
              BulkGetRequestDoc(
                  id: "test-bulkget-with-child", rev: Rev.fromString("1-b")),
              BulkGetRequestDoc(
                  id: "test-bulkget-missing-child", rev: Rev.fromString("1-c")),
              BulkGetRequestDoc(
                  id: "test-bulkget-missing-child", rev: Rev.fromString('2-c')),
              BulkGetRequestDoc(id: "test-bulkget-no-rev")
            ]),
            fromJsonT: (json) => json,
            revs: true);
        expect(response.results.length, 7);
        expect(
            response.results.where((element) =>
                element.docs.every((element) => element.doc != null)),
            hasLength(6));
        expect(
            response.results.where((element) =>
                element.docs.every((element) => element.error != null)),
            hasLength(1));
      });
    }
  ];
}
