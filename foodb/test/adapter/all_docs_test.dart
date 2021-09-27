import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'helper.dart';

void main() async {
  testEachAdapter('all-docs', (ctx) {
    test("getDocs with revs =true", () async {
      final db = ctx.db!;
      await db.put(doc: Doc(id: '1', model: {}));
      await db.put(doc: Doc(id: '2', model: {}));
      var result = await db.allDocs<Map<String, dynamic>>(
          GetAllDocsRequest(includeDocs: true), (value) => value);
      expect(result.totalRows, 2);
      expect(result.rows, hasLength(2));
    });
  });
}
