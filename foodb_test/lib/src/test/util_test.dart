import 'dart:convert';

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
      test('compact', () async {
        final db = await ctx.db('compact');
        await db.revsLimit(1);
        await db.put(
            doc: Doc(id: '1', rev: Rev.fromString('1-a'), model: {'name': '1'}),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: '1',
                rev: Rev.fromString('2-b'),
                revisions: Revisions(ids: ['b', 'a'], start: 2),
                model: {'name': '2'}),
            newEdits: false);
        await db.put(
            doc: Doc(id: '2', rev: Rev.fromString('1-a'), model: {'name': '3'}),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: '2',
                rev: Rev.fromString('2-b'),
                revisions: Revisions(ids: ['b', 'a'], start: 2),
                model: {'name': '4'}),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: '2',
                rev: Rev.fromString('2-c'),
                revisions: Revisions(ids: ['c', 'a'], start: 2),
                model: {'name': '5'}),
            newEdits: false);

        await db.compact();

        // id =1
        var doc1 = await db.get(
            id: '1', rev: '2-b', revs: true, fromJsonT: (value) => value);
        expect(doc1, isNotNull);
        expect(doc1?.revisions?.toJson(),
            Revisions(start: 2, ids: ['b']).toJson());
        expect(await db.get(id: '1', rev: '1-a', fromJsonT: (value) => value),
            isNull);

        //id =2
        expect(await db.get(id: '2', rev: '1-a', fromJsonT: (value) => value),
            isNull);

        var doc2 = await db.get(
            id: '2', rev: '2-b', revs: true, fromJsonT: (value) => value);
        expect(doc2, isNotNull);
        expect(doc2?.revisions?.toJson(),
            Revisions(start: 2, ids: ['b']).toJson());

        var doc3 = await db.get(
            id: '2', rev: '2-c', revs: true, fromJsonT: (value) => value);
        expect(doc3, isNotNull);
        expect(doc3?.revisions?.toJson(),
            Revisions(start: 2, ids: ['c']).toJson());
      });
    },
  ];
}
