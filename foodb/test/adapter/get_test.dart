import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  final ctx = CouchdbAdapterTestContext();
  // final ctx = InMemoryAdapterTestContext();
  getTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> getTest() {
  return [
    (AdapterTestContext ctx) {
      test('get()', () async {
        final db = await ctx.db('test-put-get');
        PutResponse putResponse =
            await db.put(doc: Doc(id: "test1", model: {}));
        expect(putResponse.ok, isTrue);

        Doc? doc1 = await db.get(id: 'test1', fromJsonT: (v) => {});
        expect(doc1, isNotNull);

        Doc? doc2 = await db.get(id: 'test3', fromJsonT: (v) => {});
        expect(doc2, isNull);
      });
    },
    (AdapterTestContext ctx) {
      test("bulkget with doc and error ", () async {
        final db = await ctx.db('test-bulkget');
        await db.put(
            doc: Doc(
                id: "a",
                model: {"name": "nasi lemak", "no": 3},
                rev: Rev.fromString("1-a")),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "b",
                model: {"name": "nasi lemak", "no": 3},
                rev: Rev.fromString("1-b")),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "c",
                model: {"name": "nasi lemak", "no": 3},
                rev: Rev.fromString("1-c")),
            newEdits: false);
        await db.put(doc: Doc(id: "d", model: {"name": "nasi lemak", "no": 3}));
        await db.put(
            doc: Doc(
                id: "a",
                model: {"name": "nasi lemak", "no": 3},
                rev: Rev.fromString("1-aa")),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: "b",
                model: {"name": "nasi lemak", "no": 3},
                rev: Rev.fromString("2-b"),
                revisions: Revisions(ids: ["b", "b"], start: 2)),
            newEdits: false);

        final response = await db.bulkGet<Map<String, dynamic>>(
            body: BulkGetRequest(docs: [
              BulkGetRequestDoc(id: 'a', rev: Rev.fromString("1-aa")),
              BulkGetRequestDoc(id: "a", rev: Rev.fromString("1-a")),
              BulkGetRequestDoc(id: "b", rev: Rev.fromString("2-b")),
              BulkGetRequestDoc(id: "b", rev: Rev.fromString("1-b")),
              BulkGetRequestDoc(id: "c", rev: Rev.fromString("1-c")),
              BulkGetRequestDoc(id: "d", rev: Rev.fromString("1-c"))
            ]),
            fromJsonT: (json) => json,
            revs: true);
        expect(response.results.length, 6);
        expect(
            response.results.where((element) =>
                element.docs.every((element) => element.doc != null)),
            hasLength(5));
        expect(
            response.results.where((element) =>
                element.docs.every((element) => element.error != null)),
            hasLength(1));
      });
    }
  ];
}
