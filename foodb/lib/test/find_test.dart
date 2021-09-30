import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import '../foodb_test.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext();
  findTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> findTest() {
  return [
    (FoodbTestContext ctx) {
      test('fetchDesignDoc()', () async {
        final db = await ctx.db('test-fetch-design-doc');
        await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name']),
            ddoc: "type_user_name",
            name: 'index_by_name');
        Doc<DesignDoc>? designDoc =
            await db.fetchDesignDoc(id: "_design/type_user_name");
        expect(designDoc, isNotNull);
        expect(designDoc!.model.language, 'query');
        var view = designDoc.model.views['index_by_name'];
        expect(view, isNotNull);
        expect(view is QueryDesignDocView, true);
        view as QueryDesignDocView;
        expect(view.reduce, '_count');
        expect(view.map.fields.length, 1);
        expect(view.map.fields['name'], 'asc');
        expect(view.options.def.fields.length, 1);
        expect(view.options.def.fields[0], 'name');
      });
    },
    (FoodbTestContext ctx) {
      test('fetchDesignDocs()', () async {
        final db = await ctx.db('test-fetch-all-design-docs');
        await db.createIndex(
            index: QueryViewOptionsDef(fields: ['_id']), ddoc: "type_user_id");
        await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name']),
            ddoc: "type_user_name");
        List<Doc<DesignDoc>?> designDoc = await db.fetchAllDesignDocs();
        expect(designDoc.length, equals(2));
      });
    },
    (FoodbTestContext ctx) {
      test("view", () async {
        final db = await ctx.db('test-view');
        await db.put(doc: Doc(id: "a", model: {"name": "a", "no": 99}));
        await db.put(doc: Doc(id: "b", model: {"name": "b", "no": 88}));

        //"-" is not allowed as index name
        IndexResponse indexResponse = await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name', 'no']),
            ddoc: "name_view",
            name: "name_index");
        expect(indexResponse, isNotNull);
        var query = GetViewRequest(
            startkey: ['a', 100], endkey: ['b\ufff0', 77], includeDocs: true);
        GetViewResponse<Map<String, dynamic>> result =
            await db.view("name_view", "name_index", query, (json) => json);
        expect(result.rows.length, equals(1));
        await db.put(doc: Doc(id: "c", model: {"name": "b", "no": 77}));

        GetViewResponse<Map<String, dynamic>> result2 =
            await db.view("name_view", "name_index", query, (json) => json);
        expect(result2.rows.length, equals(2));
      });
    },
    (FoodbTestContext ctx) {
      test('create with indexFields only', () async {
        final db = await ctx.db('test-index');
        IndexResponse indexResponse =
            await db.createIndex(index: QueryViewOptionsDef(fields: ['_id']));
        expect(indexResponse, isNotNull);

        Doc<Map<String, dynamic>>? doc =
            await db.get(id: indexResponse.id, fromJsonT: (json) => json);
        expect(doc, isNotNull);
      });
    },
    (FoodbTestContext ctx) {
      test('find()', () async {
        final db = await ctx.db('test-find');
        await db.createIndex(index: QueryViewOptionsDef(fields: ['_id']));
        await db.put(doc: Doc(id: "user_123", model: {}));
        FindResponse<Map<String, dynamic>> findResponse =
            await db.find<Map<String, dynamic>>(
                FindRequest(selector: {
                  '_id': {'\$regex': '^user'}
                }, sort: [
                  {"_id": "asc"}
                ]),
                (json) => json);
        expect(findResponse.docs.length > 0, isTrue);
      });
    },
    (FoodbTestContext ctx) {
      test('explain()', () async {
        final db = await ctx.db('test-explain');
        await db.createIndex(index: QueryViewOptionsDef(fields: ['_id']));
        ExplainResponse explainResponse =
            await db.explain(FindRequest(selector: {
          '_id': {'\$regex': '^user'}
        }, sort: [
          {"_id": "asc"}
        ]));
        expect(explainResponse, isNotNull);
      });
    }
  ];
}
