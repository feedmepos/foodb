import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/foodb.dart';

import 'helper.dart';

void main() async {
  const id = "put-new-edits-false";
  testEachAdapter('put-new-edits-false-with-rev', (ctx) {
    test('with Rev should be success put', () async {
      final db = ctx.db!;
      PutResponse putResponse = await db.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString("1-bb"),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);

      expect(putResponse.ok, isTrue);
    });
  });
  testEachAdapter('put-new-edits-false-with-rev', (ctx) {
    test('without Rev should catch error', () async {
      final db = ctx.db!;
      try {
        await db.put(
            doc: Doc(id: id, model: {"name": "wgg", "no": 300}),
            newEdits: false);
      } catch (err) {
        expectAsync0(() => {expect(err, isInstanceOf<AdapterException>())})();
      }
    });
  });

  testEachAdapter('put-new-edits-false-empty-revision', (ctx) {
    test('empty revisions, create new history', () async {
      final db = ctx.db!;
      await db.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('1-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      await db.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('2-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      Doc<Map<String, dynamic>>? doc =
          await db.get(id: id, fromJsonT: (val) => val, meta: true, revs: true);
      expect(doc, isNotNull);
      expect(doc!.conflicts!.length, 1);
      expect(doc.revisions!.ids.length, 1);
      db.delete(id: id, rev: Rev.fromString('2-a'));
    });
  });

  testEachAdapter('put-new-edits-false-with-revision', (ctx) {
    test('with revision, link to existing', () async {
      final db = ctx.db!;
      await db.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('1-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      await db.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('2-a'),
              model: {"name": "wgg", "no": 300},
              revisions: Revisions(start: 2, ids: ['a', 'a'])),
          newEdits: false);
      Doc<Map<String, dynamic>>? doc =
          await db.get(id: id, fromJsonT: (val) => val, meta: true, revs: true);
      expect(doc, isNotNull);
      expect(doc!.conflicts, isNull);
      expect(doc.revisions!.ids.length, 2);
      db.delete(id: id, rev: Rev.fromString('2-a'));
    });
  });
}
