import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  final ctx = CouchdbAdapterTestContext();
  // final ctx = InMemoryAdapterTestContext();
  putTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> putTest() {
  return [
    (AdapterTestContext ctx) {
      test('with Rev should be success put', () async {
        final db = await ctx.db('test-put-new-edits-true');
        await db.put(
            doc: Doc(id: "a", rev: Rev.fromString("1-a"), model: {}),
            newEdits: false);
        await db.put(doc: Doc(id: "a", rev: Rev.fromString("1-a"), model: {}));

        var doc = await db.get(id: 'a', fromJsonT: (json) => json);
        expect(doc!.rev, isNot(Rev.fromString('1-a')));
      });
    },
    (AdapterTestContext ctx) {
      const id = "put-new-edits-false";
      test('with Rev should be success put', () async {
        final db = await ctx.db('test-put-new-edits-false');
        PutResponse putResponse = await db.put(
            doc: Doc(
                id: id,
                rev: Rev.fromString("1-bb"),
                model: {"name": "wgg", "no": 300}),
            newEdits: false);

        expect(putResponse.ok, isTrue);
      });
    },
    (AdapterTestContext ctx) {
      const id = "put-new-edits-false";
      test('without Rev should catch error', () async {
        final db = await ctx.db('test-put-new-edit-false-no-rev');
        try {
          await db.put(
              doc: Doc(id: id, model: {"name": "wgg", "no": 300}),
              newEdits: false);
        } catch (err) {
          expectAsync0(() => {expect(err, isInstanceOf<AdapterException>())})();
        }
      });
    },
    (AdapterTestContext ctx) {
      const id = "put-new-edits-false";
      test('empty revisions, create new history', () async {
        final db = await ctx.db('test-put-new-edit-false-empty-revisions');
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
        Doc<Map<String, dynamic>>? doc = await db.get(
            id: id, fromJsonT: (val) => val, meta: true, revs: true);
        expect(doc, isNotNull);
        expect(doc!.conflicts!.length, 1);
        expect(doc.revisions!.ids.length, 1);
        db.delete(id: id, rev: Rev.fromString('2-a'));
      });
    },
    (AdapterTestContext ctx) {
      const id = "put-new-edits-false";
      test('with revision, link to existing', () async {
        final db = await ctx.db('test-put-new-edits-false-with-reivisions');
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
        Doc<Map<String, dynamic>>? doc = await db.get(
            id: id, fromJsonT: (val) => val, meta: true, revs: true);
        expect(doc, isNotNull);
        expect(doc!.conflicts, isNull);
        expect(doc.revisions!.ids.length, 2);
        db.delete(id: id, rev: Rev.fromString('2-a'));
      });
    },
    (AdapterTestContext ctx) {
      test(
          "put 1-a. 2-a, 3-a, then put 3-a > 2-a > 1-a reivision, then put 3-a > 2-b > 1-b, should remain 3-a > 2-a > 1-a",
          () async {
        final db = await ctx.db('test-put-with-update-revision');

        await db.put(
            doc: Doc(id: "a", rev: Rev.fromString("1-a"), model: {}),
            newEdits: false);
        await db.put(
            doc: Doc(id: "a", rev: Rev.fromString("2-a"), model: {}),
            newEdits: false);
        await db.put(
            doc: Doc(id: "a", rev: Rev.fromString("3-a"), model: {}),
            newEdits: false);

        var doc = await db.get(
            id: 'a', fromJsonT: (json) => json, revs: true, conflicts: true);
        expect(doc?.conflicts, hasLength(2));
        expect(doc?.revisions?.ids, hasLength(1));
        expect(doc?.revisions?.start, 3);
        expect(doc?.revisions?.ids[0], 'a');

        await db.put(
            doc: Doc(
                id: "a",
                rev: Rev.fromString("3-a"),
                model: {},
                revisions: Revisions(ids: ['a', 'a', 'a'], start: 3)),
            newEdits: false);
        doc = await db.get(
            id: 'a', fromJsonT: (json) => json, revs: true, conflicts: true);
        expect(doc?.conflicts?.length, isNull);
        expect(doc?.revisions?.ids, hasLength(3));
        expect(doc?.revisions?.start, 3);
        expect(doc?.revisions?.ids[0], 'a');
        expect(doc?.revisions?.ids[1], 'a');
        expect(doc?.revisions?.ids[2], 'a');
      });
    }
  ];
}
