import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  final ctx = CouchdbTestContext();
  // final ctx = InMemoryTestContext();
  utilTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> utilTest() {
  return [
    (FoodbTestContext ctx) {
      test('info()', () async {
        final db = await ctx.db('test-info');
        var result = await db.info();
        expect(result, isNotNull);
        expect(result.dbName.endsWith('test-info'), true);
      });
    },
    (FoodbTestContext ctx) {
      test('EnsureFullCommit In CouchDB adish', () async {
        final db = await ctx.db('ensure-commit');
        var ensureFullCommitResponse = await db.ensureFullCommit();
        expect(ensureFullCommitResponse.ok, isTrue);
      });
    },
    (FoodbTestContext ctx) {
      test('delete db', () async {
        final db = await ctx.db('destroy');
        await db.destroy();
        try {
          await db.info();
        } catch (err) {
          expectAsync0(() => expect(err, isA<AdapterException>()))();
        }
      });
    },
    (FoodbTestContext ctx) {
      test('revsDiff', () async {
        final db = await ctx.db('revs-diff');
        await db.put(
            doc: Doc(id: 'a', rev: Rev.fromString('1-a'), model: {}),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                rev: Rev.fromString('2-a'),
                revisions: Revisions(start: 2, ids: ['a', 'a']),
                model: {}),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                rev: Rev.fromString('3-a'),
                revisions: Revisions(start: 3, ids: ['a', 'a', 'a']),
                model: {}),
            newEdits: false);

        var revsDiff = await db.revsDiff(body: {
          'a': [
            Rev.fromString('1-a'),
            Rev.fromString('2-a'),
            Rev.fromString('3-a'),
            Rev.fromString('4-a'),
            Rev.fromString('5-a')
          ]
        });
        expect(revsDiff['a']!.missing.length, 2);
      });
    }
  ];
}
