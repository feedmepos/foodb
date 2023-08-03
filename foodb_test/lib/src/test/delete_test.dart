import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext();
  deleteTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> deleteTest() {
  return [
    (FoodbTestContext ctx) {
      test('delete()', () async {
        final db = await ctx.db('delete');
        await db.put(
            doc: Doc(id: 'test', rev: Rev.fromString('1-a'), model: {}),
            newEdits: false);
        var deleteResponse =
            await db.delete(id: 'test', rev: Rev.fromString('1-a'));
        expect(deleteResponse.ok, true);
      });
    },
    (FoodbTestContext ctx) {
      test('delete leafdoc', () async {
        final db = await ctx.db('delete-leafdoc');
        await db.put(
            doc: Doc(id: 'a', model: {}, rev: Rev.fromString('1-a')),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                model: {},
                rev: Rev.fromString('2-b'),
                revisions: Revisions(ids: ['b', 'a'], start: 2)),
            newEdits: false);
        var deleteResponse =
            await db.delete(id: 'a', rev: Rev.fromString('2-b'));
        expect(deleteResponse.ok, true);

        var doc =
            db.get<Map<String, dynamic>>(id: 'a', fromJsonT: (value) => value);
        await expectLater(
            doc,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('deleted'))));
      });
    },
    (FoodbTestContext ctx) {
      test('delete non-leafdoc, should throw error', () async {
        final db = await ctx.db('delete-non-leafdoc');
        await db.put(
            doc: Doc(id: 'a', model: {}, rev: Rev.fromString('1-a')),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                model: {},
                rev: Rev.fromString('2-b'),
                revisions: Revisions(ids: ['b', 'a'], start: 2)),
            newEdits: false);
        try {
          await db.delete(id: 'a', rev: Rev.fromString('1-a'));
        } catch (e) {
          expect(e, isA<AdapterException>());
        }
      });
    },
    (FoodbTestContext ctx) {
      test('delete doc with 2 leaf nodes', () async {
        final db = await ctx.db('delete-doc-with-2-leafdoc');
        await db.put(
            doc: Doc(id: 'a', model: {}, rev: Rev.fromString('1-a')),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                model: {},
                rev: Rev.fromString('2-b'),
                revisions: Revisions(ids: ['b', 'a'], start: 2)),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                rev: Rev.fromString('2-c'),
                revisions: Revisions(ids: ['c', 'a'], start: 2),
                model: {}),
            newEdits: false);
        var doc =
            await db.get(id: 'a', fromJsonT: (json) => json, conflicts: true);
        expect(doc?.conflicts, hasLength(1));
        expect(doc?.rev, Rev.fromString('2-c'));
        expect(doc?.conflicts?[0], Rev.fromString('2-b'));

        await db.delete(id: 'a', rev: Rev.fromString('2-c'));
        doc = await db.get(id: 'a', fromJsonT: (json) => json, conflicts: true);
        expect(doc?.rev, Rev.fromString('2-b'));
        expect(doc?.conflicts, isNull);
      });
    }
  ];
}
