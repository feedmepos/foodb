import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

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
        final db = await ctx.db('fetch-design-doc');
        await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name']),
            ddoc: 'type_user_name',
            name: 'index_by_name');
        var designDoc = await db.fetchDesignDoc(id: '_design/type_user_name');
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
        final db = await ctx.db('fetch-all-design-docs');
        await db.createIndex(
            index: QueryViewOptionsDef(fields: ['_id']), ddoc: 'type_user_id');
        await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name']),
            ddoc: 'type_user_name');
        List<Doc<DesignDoc>?> designDoc = await db.fetchAllDesignDocs();
        expect(designDoc.length, equals(2));
      });
    },
    (FoodbTestContext ctx) {
      test('view-by-startkey-and-endkey', () async {
        final db = await ctx.db('view-by-startkey-and-endkey');
        await db.put(doc: Doc(id: 'a', model: {'name': 'a', 'no': 99}));
        await db.put(doc: Doc(id: 'b', model: {'name': 'b', 'no': 88}));

        //"-" is not allowed as index name
        var indexResponse = await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name', 'no']),
            ddoc: 'name_view',
            name: 'name_index');
        expect(indexResponse, isNotNull);
        var query = GetViewRequest(
            startkey: ['a', 100], endkey: ['b\ufff0', 77], includeDocs: true);
        var result =
            await db.view('name_view', 'name_index', query, (json) => json);
        expect(result.rows.length, equals(1));
        await db.put(doc: Doc(id: 'c', model: {'name': 'b', 'no': 77}));

        var result2 =
            await db.view('name_view', 'name_index', query, (json) => json);
        expect(result2.rows.length, equals(2));
      });
    },
    (FoodbTestContext ctx) {
      test('view-by-keys', () async {
        final db = await ctx.db('view-by-keys');
        await db.put(doc: Doc(id: 'a', model: {'name': 'a', 'no': 99}));
        await db.put(doc: Doc(id: 'b', model: {'name': 'b', 'no': 88}));

        //"-" is not allowed as index name
        var indexResponse = await db.createIndex(
            index: QueryViewOptionsDef(fields: ['name', 'no']),
            ddoc: 'name_view',
            name: 'name_index');
        expect(indexResponse, isNotNull);
        var query = GetViewRequest(keys: [
          ['b', 88],
        ], includeDocs: true);
        var result =
            await db.view('name_view', 'name_index', query, (json) => json);
        expect(result.rows.length, equals(1));
        await db.put(doc: Doc(id: 'c', model: {'name': 'b', 'no': 88}));

        var result2 =
            await db.view('name_view', 'name_index', query, (json) => json);
        expect(result2.rows.length, equals(2));
      });
    },
    (FoodbTestContext ctx) {
      test('create with indexFields only', () async {
        final db = await ctx.db('index');
        var indexResponse =
            await db.createIndex(index: QueryViewOptionsDef(fields: ['_id']));
        expect(indexResponse, isNotNull);

        var doc = await db.get(id: indexResponse.id, fromJsonT: (json) => json);
        expect(doc, isNotNull);
      });
    },
    (FoodbTestContext ctx) {
      test('multiple create will update existing with indexFields only',
          () async {
        final db = await ctx.db('index');
        var indexResponse = await db.createIndex(
            index: QueryViewOptionsDef(fields: ['_id']), ddoc: 'test');
        expect(indexResponse, isNotNull);
        var doc = await db.get(id: indexResponse.id, fromJsonT: (json) => json);
        expect(doc, isNotNull);
        var allDoc = await db.allDocs(GetViewRequest(), (json) => json);
        expect(allDoc.rows, hasLength(1));
        indexResponse = await db.createIndex(
            index: QueryViewOptionsDef(fields: ['_id']), ddoc: 'test');
        allDoc = await db.allDocs(GetViewRequest(), (json) => json);
        expect(indexResponse.result, 'exists');
        expect(allDoc.rows, hasLength(1));
        expect(allDoc.rows[0].value['rev'], startsWith('1'));
      });
    },
    (FoodbTestContext ctx) {
      test('find-correct-rebuild', () async {
        final db = await ctx.db('view-by-keys');
        var doc1 = await db.put(
          doc: Doc(id: '1', model: {'type': true, 'status': 'D'}),
        );
        var doc2 = await db.put(
          doc: Doc(id: '2', model: {'type': true, 'status': 'D'}),
        );

        //"-" is not allowed as index name
        var indexResponse = await db.createIndex(
            index: QueryViewOptionsDef(fields: ['type', 'status']),
            ddoc: 'status_view',
            name: 'status_index');
        expect(indexResponse, isNotNull);
        var query = FindRequest(
            selector: AndOperator(operators: [
          EqualOperator(key: 'type', expected: true),
          EqualOperator(key: 'status', expected: 'D')
        ]));
        var result = await db.find(query, (p0) => p0);
        expect(result.docs.length, equals(2));
        await db.put(
            doc: Doc(
          id: '2',
          model: {'type': true, 'status': 'D'},
          rev: doc2.rev,
        ));

        result = await db.find(query, (p0) => p0);
        expect(result.docs.length, equals(2));
      });
    },
    (FoodbTestContext ctx) {
      group('find()', () {
        test(
            'flat selector without _id, docs with missing keys, fields of design_doc< fields of selector',
            () async {
          final db = await ctx.db('find');
          await db.createIndex(
              index: QueryViewOptionsDef(fields: ['no', 'name']));
          await db.put(
              doc: Doc(id: 'user_01', model: {
            'name': 'foo',
            'no': 3,
          }));
          await db.put(doc: Doc(id: 'admin_01', model: {'name': 'foo'}));
          await db.put(
              doc: Doc(id: 'user_02', model: {'name': 'foo', 'no': 2, 'k': 1}));

          final findResponse = await db.find<Map<String, dynamic>>(
              FindRequest(
                selector: AndOperator(operators: [
                  GreaterThanOperator(key: 'k', expected: 0),
                  EqualOperator(key: 'name', expected: 'foo'),
                  GreaterThanOperator(key: 'no', expected: 0),
                  RegexOperator(key: '_id', expected: '^user_')
                ]),
              ),
              (value) => value);

          expect(findResponse.docs.length, equals(1));
          expect(findResponse.docs.first.id, 'user_02');
        });
        test(
            'flat selector with _id, docs with missing keys, fields of designdoc < fields of selector',
            () async {
          final db = await ctx.db('find');
          await db.createIndex(
              index: QueryViewOptionsDef(fields: ['name', '_id']));
          await db.put(
              doc: Doc(id: 'user_01', model: {
            'name': 'foo',
            'no': 0,
          }));
          await db.put(doc: Doc(id: 'admin_01', model: {'name': 'foo'}));
          await db.put(
              doc: Doc(id: 'user_02', model: {'name': 'foo', 'no': 2}));
          final findResponse = await db.find<Map<String, dynamic>>(
              FindRequest(
                selector: AndOperator(operators: [
                  GreaterThanOperator(key: 'no', expected: 0),
                  EqualOperator(key: 'name', expected: 'foo'),
                  RegexOperator(key: '_id', expected: '^user')
                ]),
              ),
              (value) => value);
          expect(findResponse.docs.length, equals(1));
          expect(findResponse.docs.first.id, 'user_02');
        });

        test(
            'flat selector, nested fields, docs with missing keys, fields of designdoc < fields of selector',
            () async {
          final db = await ctx.db('find');
          await db.createIndex(
              index: QueryViewOptionsDef(fields: ['name', '_id']));
          await db.put(
              doc: Doc(id: 'user_01', model: {
            'name': {
              'first': {'name': 'foo'}
            },
            'no': 2,
          }));
          await db.put(doc: Doc(id: 'admin_01', model: {'name': 'foo'}));
          await db.put(
              doc: Doc(id: 'user_02', model: {'name': 'foo', 'no': 0}));
          final findResponse = await db.find<Map<String, dynamic>>(
              FindRequest(
                selector: AndOperator(operators: [
                  GreaterThanOperator(key: 'no', expected: 0),
                  EqualOperator(key: 'name.first.name', expected: 'foo'),
                  RegexOperator(key: '_id', expected: '^user')
                ]),
              ),
              (value) => value);
          expect(findResponse.docs.length, equals(1));
          expect(findResponse.docs.first.id, 'user_01');
        });

        test('nested selector with _id, docs with missing keys, call all_docs',
            () async {
          final db = await ctx.db('find');
          await db.createIndex(
              index: QueryViewOptionsDef(fields: ['name', 'no']));
          await db.put(
              doc: Doc(id: 'user_01', model: {
            'name': 'foo',
            'no': 1,
          }));
          await db.put(doc: Doc(id: 'admin_01', model: {'name': 'foo'}));
          await db.put(
              doc: Doc(id: 'user_02', model: {'name': 'foo', 'no': 2}));
          final findResponse = await db.find<Map<String, dynamic>>(
              FindRequest(
                selector: AndOperator(operators: [
                  AndOperator(operators: [
                    EqualOperator(key: 'name', expected: 'foo'),
                    GreaterThanOperator(key: 'no', expected: 0),
                    AndOperator(operators: [
                      RegexOperator(key: '_id', expected: '^user')
                    ])
                  ])
                ]),
              ),
              (value) => value);

          expect(findResponse.docs.length, equals(2));
          expect(findResponse.docs.first.id, 'user_01');
          expect(findResponse.docs[1].id, 'user_02');
        });
        test(
            'nested selector without _id, docs with missing keys, fields of designdoc = first layer of selector',
            () async {
          final db = await ctx.db('find');
          await db.createIndex(
              index: QueryViewOptionsDef(fields: ['name', 'k']));
          await db.put(
              doc: Doc(id: 'user_01', model: {'name': 'foo', 'no': 1, 'k': 1}));
          await db.put(
              doc: Doc(id: 'admin_01', model: {'name': 'food', 'k': 2}));
          await db.put(
              doc: Doc(id: 'user_02', model: {'name': 'foo', 'no': 2, 'k': 3}));
          final findResponse = await db.find<Map<String, dynamic>>(
              FindRequest(
                selector: AndOperator(operators: [
                  EqualOperator(key: 'name', expected: 'foo'),
                  GreaterThanOperator(key: 'k', expected: 0),
                  AndOperator(operators: [
                    GreaterThanOperator(key: 'no', expected: 0),
                    AndOperator(operators: [
                      RegexOperator(key: '_id', expected: '^user')
                    ])
                  ])
                ]),
              ),
              (value) => value);

          expect(findResponse.docs.length, equals(2));
          expect(findResponse.docs.first.id, 'user_01');
          expect(findResponse.docs[1].id, 'user_02');
        });

        test(
            'nested selector, nested field, docs with missing keys, call all_docs',
            () async {
          final db = await ctx.db('find');
          await db.createIndex(
              index: QueryViewOptionsDef(fields: ['name', 'no']));
          await db.put(
              doc: Doc(id: 'user_01', model: {
            'name': {
              'first': {'name': 'foo'}
            },
            'no': 1,
          }));
          await db.put(doc: Doc(id: 'admin_01', model: {'name': 'foo'}));
          await db.put(
              doc: Doc(id: 'user_02', model: {'name': 'foo', 'no': 2}));
          final findResponse = await db.find<Map<String, dynamic>>(
              FindRequest(
                selector: AndOperator(operators: [
                  AndOperator(operators: [
                    EqualOperator(key: 'name.first.name', expected: 'foo'),
                    GreaterThanOperator(key: 'no', expected: 0),
                    AndOperator(operators: [
                      RegexOperator(key: '_id', expected: '^user')
                    ])
                  ])
                ]),
              ),
              (value) => value);

          expect(findResponse.docs.length, equals(1));
          expect(findResponse.docs.first.id, 'user_01');
        });
      });
    },
    (FoodbTestContext ctx) {
      group('explain()', () {
        test('order of fields should not affect selection', () async {
          final db = await ctx.db('explain');
          var index = await db.createIndex(
              name: 'id-name-index',
              index: QueryViewOptionsDef(fields: ['_id', 'name']));
          var index2 = await db.createIndex(
              name: 'name-id-index',
              index: QueryViewOptionsDef(fields: ['name', '_id']));
          var explainResponse = await db.explain(FindRequest(
              selector: AndOperator(operators: [
                EqualOperator(key: 'name', expected: 'nasi'),
                RegexOperator(
                  key: '_id',
                  expected: '^user',
                )
              ]),
              sort: [
                {'_id': 'asc'}
              ]));
          var chosen =
              index.id.compareTo(index2.id) < 0 ? index.name : index2.name;
          expect(explainResponse.index.name, chosen);
        });
        test(
            'selected design-doc fields should less or equal to selector and ignore _id',
            () async {
          final db = await ctx.db('explain');
          await db.createIndex(
              name: 'id-name-index',
              index: QueryViewOptionsDef(fields: ['name', '_id']));
          await db.createIndex(
              name: 'id-name-k-index',
              index: QueryViewOptionsDef(fields: ['no', 'name', 'k']));

          var explainResponse = await db.explain(FindRequest(
              selector: AndOperator(operators: [
                EqualOperator(key: 'no', expected: 100),
                RegexOperator(
                  key: 'name',
                  expected: '^user',
                )
              ]),
              sort: [
                {'_id': 'asc'}
              ]));
          expect(explainResponse.index.name, 'id-name-index');
        });
        test('should return all_docs if no suitable design docs', () async {
          final db = await ctx.db('explain');
          await db.createIndex(
              name: 'id-name-index',
              index: QueryViewOptionsDef(fields: ['k', '_id']));
          await db.createIndex(
              name: 'id-name-k-index',
              index: QueryViewOptionsDef(fields: ['no', 'name', 'k']));

          var explainResponse = await db.explain(FindRequest(
              selector: AndOperator(operators: [
                EqualOperator(key: 'no', expected: 100),
                RegexOperator(
                  key: 'name',
                  expected: '^user',
                )
              ]),
              sort: [
                {'_id': 'asc'}
              ]));
          expect(explainResponse.index.name, 'all_docs');
        });
      });
    }
  ];
}
