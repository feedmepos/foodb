import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext();
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
    },
    (FoodbTestContext ctx) {
      test('rev limit and compaction', () async {
        final db = await ctx.db('rev-limit-and-compaction');
        putDoc(List<String> revs) {
          var revisions = Revisions(
            start: int.parse(revs[0].split('-')[0]),
            ids: revs.map((e) => e.split('-')[1]).toList(),
          );
          var rev = Rev.fromString(revs[0]);
          return db.put(
              doc: Doc(
                id: 'a',
                rev: rev,
                model: {},
                revisions: revisions,
              ),
              newEdits: false);
        }

        getDoc([String? rev]) {
          return db.get(
            id: 'a',
            fromJsonT: (json) => json,
            rev: rev,
            revsInfo: true,
            revs: true,
            conflicts: true,
            meta: true,
          );
        }

        await putDoc(['1-a']);
        await putDoc(['2-a', '1-a']);
        await putDoc(['3-a', '2-a', '1-a']);
        await putDoc(['4-a', '3-a', '2-a', '1-a']);
        await putDoc(['3-b', '2-a', '1-a']);
        await putDoc(['4-b', '3-b', '2-a', '1-a']);
        // rev limit will not remove revinfos, just change revisions ouput, doc still exist
        await db.revsLimit(2);
        var winner = await getDoc();
        var winnerUsingRev = await getDoc('4-b');
        var winnerBranch = await getDoc('3-b');
        var commonAccestor = await getDoc('2-a');
        var conflictLeaf = await getDoc('4-a');
        var conflictBranch = await getDoc('3-a');
        expect(winner, isNotNull);
        expect(winner!.conflicts, hasLength(1));
        expect(winnerUsingRev, isNotNull);
        expect(winnerBranch, isNotNull);
        expect(commonAccestor, isNotNull);
        expect(conflictLeaf, isNotNull);
        expect(conflictBranch, isNotNull);
        expect(winner.revsInfo, hasLength(4));
        expect(winnerUsingRev!.revsInfo, isNull);
        expect(winnerBranch!.revsInfo, isNull);
        expect(commonAccestor!.revsInfo, isNull);
        expect(conflictLeaf!.revsInfo, isNull);
        expect(conflictBranch!.revsInfo, isNull);
        expect(winner.revisions!.ids, hasLength(2));
        expect(winnerBranch.revisions!.ids, hasLength(2));
        expect(commonAccestor.revisions!.ids, hasLength(2));
        expect(conflictLeaf.revisions!.ids, hasLength(2));
        expect(conflictBranch.revisions!.ids, hasLength(2));

        // compact before rev limit will not reduce revisions.ids, doc disappear
        await db.revsLimit(100);
        await db.compact();
        await Future.delayed(Duration(seconds: 1));
        winner = await getDoc();
        winnerBranch = await getDoc('3-b');
        commonAccestor = await getDoc('2-a');
        conflictLeaf = await getDoc('4-a');
        conflictBranch = await getDoc('3-a');
        expect(winner, isNotNull);
        expect(conflictLeaf, isNotNull);
        expect(winnerBranch, isNull);
        expect(commonAccestor, isNull);
        expect(conflictBranch, isNull);
        expect(winner!.revisions!.ids, hasLength(4));
        expect(conflictLeaf!.revisions!.ids, hasLength(4));

        // compact after change rev limit, revisions id dissappear
        await db.revsLimit(2);
        await db.compact();
        await Future.delayed(Duration(seconds: 1));
        winner = await getDoc();
        conflictLeaf = await getDoc('4-a');
        expect(winner!.revisions!.ids, hasLength(2));
        expect(conflictLeaf!.revisions!.ids, hasLength(2));
      });
    },
  ];
}
