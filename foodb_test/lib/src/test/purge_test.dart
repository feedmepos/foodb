@Timeout(Duration(seconds: 1000))
import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';
import 'package:foodb/foodb.dart';

void main() {
  final ctx = CouchdbTestContext();
  // final ctx = InMemoryTestContext(latency: Duration(seconds: 1));
  purgeTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> purgeTest() {
  return [
    (FoodbTestContext ctx) {
      test('purge deleted conflicts', () async {
        final db = await ctx.db('purge-conflict-doc');
        // create doc with conflicts
        await db.put(
            doc: Doc(id: 'a', rev: Rev.fromString('1-a'), model: {}),
            newEdits: false);
        await db.put(
            doc: Doc(
                id: 'a',
                rev: Rev.fromString('2-a'),
                model: {},
                revisions: Revisions(start: 2, ids: ['a', 'a'])),
            newEdits: false);
        await db.put(
            doc: Doc(id: 'a', rev: Rev.fromString('3-a'), model: {}),
            newEdits: false);
        var doc = await db.get(
          id: 'a',
          fromJsonT: (json) => json,
          revs: true,
          conflicts: true,
          meta: true,
          revsInfo: true,
        );
        expect(doc?.conflicts, hasLength(1));
        // delete conflicts
        final deletes = (doc?.conflicts ?? []).map((rev) async {
          await db.delete(id: doc!.id, rev: rev);
        }).toList();
        await Future.wait(deletes);
        var deletedConflictDoc = await db.get(
          id: doc!.id,
          fromJsonT: (json) => json,
          revs: true,
          conflicts: true,
          meta: true,
          revsInfo: true,
        );
        expect(deletedConflictDoc?.deletedConflicts?.length, 1);
        // purge conflicts
        final purgePayload = {
          deletedConflictDoc!.id: [
            ...(deletedConflictDoc.deletedConflicts ?? <Rev>[])
                .map((rev) => rev.toString()),
            '2-xxx', // invalid rev to be ignored without exception
          ],
          'invalid-doc': [
            '1-xxx'
          ], // invalid doc expected to be ignored without exception
        };
        final purgeResult = await db.purge(purgePayload);
        expect(purgeResult.purged?[deletedConflictDoc.id]?.length, 1);
        expect(purgeResult.purged?['invalid-doc']?.length, 0);
        var purgedDoc = await db.get(
          id: doc.id,
          fromJsonT: (json) => json,
          revs: true,
          conflicts: true,
          meta: true,
          revsInfo: true,
        );
        expect(purgedDoc, isNotNull);
        expect(purgedDoc?.conflicts, isNull);
        expect(purgedDoc?.deletedConflicts, isNull);
      });
    },
  ];
}
