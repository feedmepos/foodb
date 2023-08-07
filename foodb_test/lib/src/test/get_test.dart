import 'dart:io';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

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
        final db = await ctx.db('put-get');
        var putResponse = await db.put(doc: Doc(id: 'test-get', model: {}));
        expect(putResponse.ok, isTrue);

        var doc1 = await db.get(id: 'test-get', fromJsonT: (v) => {});
        expect(doc1, isNotNull);

        await expectLater(
            db.get(id: 'test-get-empty', fromJsonT: (v) => {}),
            throwsA(predicate((e) =>
                e is AdapterException && e.reason!.contains('missing'))));

        await db.delete(id: doc1.id, rev: doc1.rev!);

        await expectLater(
            db.get(id: doc1.id, fromJsonT: (v) => {}),
            throwsA(predicate((e) =>
                e is AdapterException && e.reason!.contains('deleted'))));

        var oldDeletedDoc = await db.get(
            id: doc1.id, rev: doc1.rev.toString(), fromJsonT: (v) => {});
        expect(oldDeletedDoc, isNotNull);
      });
    },
    (FoodbTestContext ctx) {
      test('get() utf-8 character', () async {
        final db = await ctx.db('put-get-chinese');
        var putResponse =
            await db.put(doc: Doc(id: 'test-get', model: {'a': '這是中文'}));
        expect(putResponse.ok, isTrue);

        var doc1 = await db.get(id: 'test-get', fromJsonT: (v) => v);
        expect(doc1, isNotNull);
        expect(doc1.model['a'], '這是中文');
      });
    },
    (FoodbTestContext ctx) {
      test('bulkget with doc and error ', () async {
        final db = await ctx.db('bulkget');
        await db.put(
            doc: Doc(
                id: 'test-bulkget-conflict',
                model: {},
                rev: Rev.fromString('1-a')),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'test-bulkget-conflict',
                model: {},
                rev: Rev.fromString('1-aa')),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'test-bulkget-with-child',
                model: {},
                rev: Rev.fromString('1-b')),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'test-bulkget-with-child',
                model: {},
                rev: Rev.fromString('2-b'),
                revisions: Revisions(ids: ['b', 'b'], start: 2)),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'test-bulkget-missing-child',
                model: {},
                rev: Rev.fromString('1-c')),
            newEdits: false);
        await db.put(doc: Doc(id: 'test-bulkget-no-rev', model: {}));
        var toDelete =
            await db.put(doc: Doc(id: 'test-bulkget-deleted', model: {}));
        await db.delete(id: toDelete.id, rev: toDelete.rev);

        final response = await db.bulkGet<Map<String, dynamic>>(
            body: BulkGetRequest(docs: [
              BulkGetRequestDoc(
                  id: 'test-bulkget-conflict', rev: Rev.fromString('1-aa')),
              BulkGetRequestDoc(
                  id: 'test-bulkget-conflict', rev: Rev.fromString('1-a')),
              BulkGetRequestDoc(
                  id: 'test-bulkget-with-child', rev: Rev.fromString('2-b')),
              BulkGetRequestDoc(
                  id: 'test-bulkget-with-child', rev: Rev.fromString('1-b')),
              BulkGetRequestDoc(
                  id: 'test-bulkget-missing-child', rev: Rev.fromString('1-c')),
              BulkGetRequestDoc(
                  id: 'test-bulkget-missing-child', rev: Rev.fromString('2-c')),
              BulkGetRequestDoc(id: 'test-bulkget-no-rev'),
              BulkGetRequestDoc(id: 'test-bulkget-deleted')
            ]),
            fromJsonT: (json) => json,
            revs: true);
        expect(response.results.length, 8);
        expect(
            response.results.where((element) =>
                element.docs.every((element) => element.doc != null)),
            hasLength(7));
        expect(
            response.results.where((element) => element.docs.every((element) =>
                element.error?.reason.contains('missing') ?? false)),
            hasLength(1));
      });
    },
    (FoodbTestContext ctx) {
      test('bulkGet() improve json decode', () async {
        FoodbDebug.logLevel = LOG_LEVEL.debug;
        final db = await ctx.db('bulk-get-large-json', persist: true);
        if ((await db.info()).docCount == 0) {
          var docs = <Doc<Map<String, dynamic>>>[];
          for (var i = 0; i <= 500; ++i) {
            docs.add(getLargeDoc('$i'));
            if (i % 100 == 0) {
              await db.bulkDocs(body: docs);
              docs = [];
            }
          }
        }
        final allDoc = await db.allDocs(GetViewRequest(), (json) => json);

        final result = await db.bulkGet(
            body: BulkGetRequest(
                docs: allDoc.rows
                    .map((e) => BulkGetRequestDoc(
                        id: e.id, rev: Rev.fromString(e.value['rev'])))
                    .toList()),
            fromJsonT: (json) => json);
        expect(result, isNotNull);
      }, timeout: Timeout(Duration(minutes: 5)));
    },
  ];
}
