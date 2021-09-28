import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';

import 'adapter_test.dart';

void main() {
  final ctx = CouchdbAdapterTestContext();
  // final ctx = InMemoryAdapterTestContext();
  utilTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> utilTest() {
  return [
    (AdapterTestContext ctx) {
      test('info()', () async {
        final db = await ctx.db('test-info');
        var result = await db.info();
        expect(result, isNotNull);
        expect(result.dbName, equals('test-info'));
      });
    },
    (AdapterTestContext ctx) {
      test('EnsureFullCommit In CouchDB adish', () async {
        final db = await ctx.db('test-ensure-commit');
        EnsureFullCommitResponse ensureFullCommitResponse =
            await db.ensureFullCommit();
        expect(ensureFullCommitResponse.ok, isTrue);
      });
    },
    (AdapterTestContext ctx) {
      test('delete db', () async {
        final db = await ctx.db('test-destroy');
        await db.destroy();
        try {
          await db.info();
        } catch (err) {
          expectAsync0(() => expect(err, isInstanceOf<AdapterException>()))();
        }
      });
    },
    (AdapterTestContext ctx) {
      test('revsDiff', () async {
        final db = await ctx.db('test-revs-diff');
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

        Map<String, RevsDiff> revsDiff = await db.revsDiff(body: {
          "a": [
            Rev.fromString('1-a'),
            Rev.fromString('2-a'),
            Rev.fromString('3-a'),
            Rev.fromString('4-a'),
            Rev.fromString('5-a')
          ]
        });
        expect(revsDiff["a"]!.missing.length, 2);
      });
    }
  ];
}
