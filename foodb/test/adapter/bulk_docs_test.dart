import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/foodb.dart';

import 'helper.dart';

void main() async {
  testEachAdapter('bulk-docs-new-edits-false', (ctx) {
    test('bulkdocs() with newEdits= false', () async {
      final db = ctx.db!;
      List<Doc<Map<String, dynamic>>> newDocs = [];
      newDocs.add(Doc(
          id: 'test2',
          rev: Rev.fromString('1-zu21xehvdaine5smjxy9htiegd4rptkm5'),
          model: {
            'name': 'test test',
            'no': 1111,
          },
          revisions: Revisions(start: 1, ids: [
            'zu21xehvdaine5smjxy9htiegd4rptkm5',
            'zu21xehvdaine5smjxy9htiegd4rptkm5'
          ])));
      newDocs.add(Doc(
          id: 'test7',
          rev: Rev.fromString('0-sasddsdsdfdfdsfdffdd'),
          model: {
            'name': 'test test asdfgh',
            'no': 2212,
          },
          revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])));
      newDocs.add(Doc(
          id: 'test5',
          rev: Rev.fromString('0-sasddsdsdfdfdsfdffdd'),
          model: {
            'name': 'test test 5',
            'no': 222,
          },
          revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])));
      BulkDocResponse bulkDocResponse =
          await db.bulkDocs(body: newDocs, newEdits: false);
      expect(bulkDocResponse.putResponses, []);
    });
  });
  testEachAdapter('bulk-docs-new-edits-false', (ctx) {
    test('bulkdocs() with newEdits =true', () async {
      final db = ctx.db!;
      var bulkdocResponse = await db.bulkDocs(body: [
        new Doc<Map<String, dynamic>>(
            id: "test 1", model: {"name": "beefy", "no": 999}),
        new Doc<Map<String, dynamic>>(
            id: "test 2", model: {"name": "soda", "no": 999}),
      ], newEdits: true);

      expect(bulkdocResponse.putResponses.length, 2);
    });
  });
}
