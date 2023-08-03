import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext();
  bulkDocTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> bulkDocTest() {
  return [
    (FoodbTestContext ctx) {
      test('bulkdocs with newEdits = false', () async {
        final db = await ctx.db('bulkdocs-new-edits-false');
        await db.put(
            doc: Doc(id: 'a', model: {}, rev: Rev.fromString('1-a')),
            newEdits: false);
        await db.put(
            doc: Doc(id: 'b', model: {}, rev: Rev.fromString('1-b')),
            newEdits: false);
        await db.bulkDocs(body: [
          Doc(
              id: 'a',
              rev: Rev.fromString('2-a'),
              model: {},
              revisions: Revisions(ids: ['a', 'a'], start: 2)),
          Doc(
              id: 'b',
              rev: Rev.fromString('2-b'),
              deleted: true,
              model: {},
              revisions: Revisions(ids: ['b', 'b'], start: 2)),
          Doc(id: 'c', rev: Rev.fromString('1-c'), model: {}),
          Doc(
              id: 'd',
              rev: Rev.fromString('3-d'),
              model: {},
              revisions: Revisions(ids: ['d', 'c'], start: 3))
        ], newEdits: false);

        var doc1 = await db.get(id: 'a', fromJsonT: (value) => value);
        expect(doc1?.rev?.index, 2);

        var doc2 = db.get(id: 'b', fromJsonT: (value) => value);
        await expectLater(
            doc2,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('deleted'))));

        var doc3 = await db.get(id: 'c', fromJsonT: (value) => value);
        expect(doc3, isNotNull);

        var doc4 =
            await db.get(id: 'd', fromJsonT: (value) => value, revsInfo: true);
        expect(doc4?.rev.toString(), '3-d');
        expect(doc4?.revsInfo?[0].rev, Rev.fromString('3-d'));
        expect(doc4?.revsInfo?[0].status, 'available');
        expect(doc4?.revsInfo?[1].rev, Rev.fromString('2-c'));
        expect(doc4?.revsInfo?[1].status, 'missing');
      });
    },
  ];
}
