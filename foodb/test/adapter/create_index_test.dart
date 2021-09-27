import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'helper.dart';

void main() async {
  testEachAdapter('fetch-design-doc', (ctx) {
    test('fetchDesignDoc()', () async {
      final db = ctx.db!;
      await db.createIndex(indexFields: ['name'], ddoc: "type_user_name");
      Doc<DesignDoc>? designDoc =
          await db.fetchDesignDoc(id: "_design/type_user_name");
      expect(designDoc, isNotNull);
    });
  });

  testEachAdapter('fetch-all-design-doc', (ctx) {
    test('fetchAllDesignDocs()', () async {
      final db = ctx.db!;
      await db.createIndex(indexFields: ['_id'], ddoc: "type_user_id");
      await db.createIndex(indexFields: ['name'], ddoc: "type_user_name");
      List<Doc<DesignDoc>?> designDoc = await db.fetchAllDesignDocs();
      expect(designDoc.length, equals(2));
    });
  });
}
