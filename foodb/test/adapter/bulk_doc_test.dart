import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  // final ctx = CouchdbAdapterTestContext();
  final ctx = InMemoryAdapterTestContext();
  bulkDocTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> bulkDocTest() {
  return [
    (AdapterTestContext ctx) {
      test('bulkdocs with newEdits = false', () async {
        final db = await ctx.db('bulkdocs-new-edits-false');
        await db.put(
            doc: Doc(id: "a", model: {}, rev: Rev.fromString("1-a")),
            newEdits: false);
        await db.put(
            doc: Doc(id: "b", model: {}, rev: Rev.fromString("1-b")),
            newEdits: false);
        BulkDocResponse bulkDocsResponse = await db.bulkDocs(body: [
          Doc(
              id: "a",
              rev: Rev.fromString("2-a"),
              model: {},
              revisions: Revisions(ids: ['a', 'a'], start: 2)),
          Doc(
              id: "b",
              rev: Rev.fromString("2-b"),
              deleted: true,
              model: {},
              revisions: Revisions(ids: ['b', 'b'], start: 2)),
          Doc(id: "c", rev: Rev.fromString("1-c"), model: {}),
          Doc(
              id: "d",
              rev: Rev.fromString("3-d"),
              model: {},
              revisions: Revisions(ids: ['d', 'c'], start: 3))
        ], newEdits: false);

        Doc<Map<String, dynamic>>? doc1 =
            await db.get(id: "a", fromJsonT: (value) => value);
        expect(doc1?.rev?.index, 2);

        Doc<Map<String, dynamic>>? doc2 =
            await db.get(id: "b", fromJsonT: (value) => value);
        expect(doc2, isNull);

        Doc<Map<String, dynamic>>? doc3 =
            await db.get(id: "c", fromJsonT: (value) => value);
        expect(doc3, isNotNull);

        Doc<Map<String, dynamic>>? doc4 =
            await db.get(id: "d", fromJsonT: (value) => value, revsInfo: true);
        expect(doc4?.rev.toString(), "3-d");
        expect(doc4?.revsInfo?[0].rev, Rev.fromString("3-d"));
        expect(doc4?.revsInfo?[0].status, 'available');
        expect(doc4?.revsInfo?[1].rev, Rev.fromString("2-c"));
        expect(doc4?.revsInfo?[1].status, 'missing');
      });
    },
  ];
}
