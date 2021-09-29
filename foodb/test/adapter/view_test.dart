import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  // final ctx = CouchdbAdapterTestContext();
  final ctx = InMemoryAdapterTestContext();
  viewTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> viewTest() {
  return [
    (AdapterTestContext ctx) {
      test('fetchDesignDoc()', () async {
        final db = await ctx.db('test-fetch-design-doc');
        await db.createIndex(indexFields: ['name'], ddoc: "type_user_name");
        Doc<DesignDoc>? designDoc =
            await db.fetchDesignDoc(id: "_design/type_user_name");
        expect(designDoc, isNotNull);
      });
    },
    (AdapterTestContext ctx) {
      test('fetchpDesignDocs()', () async {
        final db = await ctx.db('test-fetch-all-design-docs');
        await db.createIndex(indexFields: ['_id'], ddoc: "type_user_id");
        await db.createIndex(indexFields: ['name'], ddoc: "type_user_name");
        List<Doc<DesignDoc>?> designDoc = await db.fetchAllDesignDocs();
        expect(designDoc.length, equals(2));
      });
    },
    (AdapterTestContext ctx) {
      test("view", () async {
        final db = await ctx.db('test-view');
        await db.put(doc: Doc(id: "a", model: {"name": "a", "no": 99}));
        await db.put(doc: Doc(id: "b", model: {"name": "b", "no": 77}));

        //"-" is not allowed as index name
        IndexResponse indexResponse = await db.createIndex(
            indexFields: ["name", "no"], ddoc: "name_view", name: "name_index");
        expect(indexResponse, isNotNull);

        Doc<Map<String, dynamic>>? doc =
            await db.get(id: indexResponse.id, fromJsonT: (json) => json);
        print(doc?.toJson((value) => value));
        expect(doc, isNotNull);

        GetViewResponse<Map<String, dynamic>> result = await db.view(
            "name_view",
            "name_index",
            GetViewRequest(
                startkey: ["a", 99], endkey: ["b", 76], includeDocs: true),
            (json) => json);

        await db.put(doc: Doc(id: "c", model: {"name": "c", "no": 55}));

        GetViewResponse<Map<String, dynamic>> result2 = await db.view(
            "name_view",
            "name_index",
            GetViewRequest(
              startkey: ["a", 99],
              endkey: ["b", 76],
            ),
            (json) => json);

        expect(result.rows.length, equals(1));
        expect(result2.rows.length, equals(1));
      });
    },
    (AdapterTestContext ctx) {
      test("getDocs with revs =true", () async {
        final db = await ctx.db('test-all-docs');
        await db.put(doc: Doc(id: '1', model: {}));
        await db.put(
            doc: Doc(id: '2', rev: Rev.fromString('1-a'), model: {}),
            newEdits: false);
        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        expect(result.totalRows, 2);
        expect(result.rows, hasLength(2));
        await db.put(
            doc: Doc(id: '3', rev: Rev.fromString('1-a'), model: {}),
            newEdits: false);
        result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        expect(result.totalRows, 3);
        expect(result.rows, hasLength(3));
        await db.delete(id: '3', rev: Rev.fromString('1-a'));
        result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        expect(result.totalRows, 2);
        expect(result.rows, hasLength(2));
        await db.put(
            doc: Doc(id: '2', rev: Rev.fromString('1-b'), model: {}),
            newEdits: false);
        result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        expect(result.totalRows, 2);
        expect(result.rows, hasLength(2));
      });
    },
    (AdapterTestContext ctx) {
      test('create with indexFields only', () async {
        final db = await ctx.db('test-index');
        IndexResponse indexResponse =
            await db.createIndex(indexFields: ["_id"]);
        expect(indexResponse, isNotNull);

        Doc<Map<String, dynamic>>? doc =
            await db.get(id: indexResponse.id, fromJsonT: (json) => json);
        print(doc?.toJson((value) => value));
        expect(doc, isNotNull);
      });
    }
  ];
}
