import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/foodb.dart';

import 'helper.dart';

void main() async {
  testEachAdapter('bulk-docs-new-edits-false', (ctx) {
    test("getDocs with revs =true", () async {
      final db = ctx.db!;
      await db.put(
          doc: Doc(
              id: "a",
              model: {"name": "nasi lemak", "no": 3},
              rev: Rev.fromString("1-a")),
          newEdits: false);
      await db.put(
          doc: Doc(
              id: "b",
              model: {"name": "nasi lemak", "no": 3},
              rev: Rev.fromString("1-b")),
          newEdits: false);
      await db.put(
          doc: Doc(
              id: "c",
              model: {"name": "nasi lemak", "no": 3},
              rev: Rev.fromString("1-c")),
          newEdits: false);
      await db.put(doc: Doc(id: "d", model: {"name": "nasi lemak", "no": 3}));
      await db.put(
          doc: Doc(
              id: "a",
              model: {"name": "nasi lemak", "no": 3},
              rev: Rev.fromString("1-aa")),
          newEdits: false);
      await db.put(
          doc: Doc(
              id: "b",
              model: {"name": "nasi lemak", "no": 3},
              rev: Rev.fromString("2-b"),
              revisions: Revisions(ids: ["b", "b"], start: 2)),
          newEdits: false);

      final response = await db.bulkGet<Map<String, dynamic>>(body: [
        {"id": "a", "rev": Rev.fromString("1-aa")},
        {"id": "a", "rev": Rev.fromString("1-a")},
        {"id": "b", "rev": Rev.fromString("2-b")},
        {"id": "b", "rev": Rev.fromString("1-b")},
        {"id": "c", "rev": Rev.fromString("1-c")}
      ], fromJsonT: (json) => json, revs: true);
      print(response.toJson((json) => json));
      expect(response.results.length, 5);
    });
  });
}
