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
        var doc1 = await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.delete(id: doc1.id, rev: doc1.rev);
        var result = await db.info();
        expect(result, isNotNull);
        expect(result.dbName.endsWith('test-info'), true);
        expect(result.docCount, 1);
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
        expect(winner, isNotNull);
        expect(winner!.conflicts, hasLength(1));
        expect(winner.revsInfo, hasLength(4));
        expect(winner.revisions!.ids, hasLength(2));

        var winnerUsingRev = await getDoc('4-b');
        expect(winnerUsingRev, isNotNull);
        expect(winnerUsingRev!.revsInfo, isNull);

        var winnerBranch = await getDoc('3-b');
        expect(winnerBranch, isNotNull);
        expect(winnerBranch!.revsInfo, isNull);
        expect(winnerBranch.revisions!.ids, hasLength(2));

        var commonAccestor = await getDoc('2-a');
        expect(commonAccestor, isNotNull);
        expect(commonAccestor!.revsInfo, isNull);
        expect(commonAccestor.revisions!.ids, hasLength(2));

        var conflictLeaf = await getDoc('4-a');
        expect(conflictLeaf, isNotNull);
        expect(conflictLeaf!.revsInfo, isNull);
        expect(conflictLeaf.revisions!.ids, hasLength(2));

        var conflictBranch = await getDoc('3-a');
        expect(conflictBranch, isNotNull);
        expect(conflictBranch!.revsInfo, isNull);
        expect(conflictBranch.revisions!.ids, hasLength(2));

        // compact before rev limit will not reduce revisions.ids, doc disappear
        await db.revsLimit(100);
        await db.compact();
        await Future.delayed(Duration(seconds: 1));
        winner = await getDoc();
        expect(winner, isNotNull);
        expect(winner!.revisions!.ids, hasLength(4));

        var winnerBranch2 = getDoc('3-b');
        await expectLater(
            winnerBranch2,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('missing'))));

        var commonAccestor2 = getDoc('2-a');
        await expectLater(
            commonAccestor2,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('missing'))));

        conflictLeaf = await getDoc('4-a');
        expect(conflictLeaf, isNotNull);
        expect(conflictLeaf!.revisions!.ids, hasLength(4));

        var conflictBranch2 = getDoc('3-a');
        await expectLater(
            conflictBranch2,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('missing'))));

        // compact after change rev limit, revisions id dissappear
        await db.revsLimit(2);
        await db.compact();
        await Future.delayed(Duration(seconds: 1));
        winner = await getDoc();
        conflictLeaf = await getDoc('4-a');
        expect(winner!.revsInfo, hasLength(2));
        expect(winner.revisions!.ids, hasLength(2));
        expect(conflictLeaf!.revisions!.ids, hasLength(2));

        // changing rev limit will rerun compacting since start
        await putDoc(['5-b', '4-b', '3-b', '2-a', '1-a']);
        await db.revsLimit(1);
        await db.compact();
        await Future.delayed(Duration(seconds: 1));
        winner = await getDoc();
        expect(winner!.revsInfo, hasLength(1));
        expect(winner.revisions!.ids, hasLength(1));
      });
    },
    (FoodbTestContext ctx) {
      test('rev limit and auto compaction', () async {
        final db =
            await ctx.db('rev-limit-and-auto-compaction', autoCompaction: true);
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

        await db.revsLimit(2);
        await putDoc(['1-a']);
        await putDoc(['2-a', '1-a']);
        await putDoc(['3-a', '2-a', '1-a']);
        await putDoc(['4-a', '3-a', '2-a', '1-a']);
        await putDoc(['3-b', '2-a', '1-a']);
        await putDoc(['4-b', '3-b', '2-a', '1-a']);
        if (ctx is CouchdbTestContext) {
          await db.compact();
        }
        await Future.delayed(Duration(seconds: 1));
        var winner = await getDoc();
        expect(winner, isNotNull);
        expect(winner!.revisions!.ids, hasLength(2));

        var winnerBranch = getDoc('3-b');
        await expectLater(
            winnerBranch,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('missing'))));

        var commonAccestor = getDoc('2-a');
        await expectLater(
            commonAccestor,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('missing'))));

        var conflictLeaf = await getDoc('4-a');
        expect(conflictLeaf, isNotNull);
        expect(conflictLeaf!.revisions!.ids, hasLength(2));

        var conflictBranch = getDoc('3-a');
        await expectLater(
            conflictBranch,
            throwsA(predicate(
                (e) => e is AdapterException && e.error.contains('missing'))));
      });
    },
  ];
}
