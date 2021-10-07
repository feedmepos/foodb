import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';
import 'package:foodb/foodb.dart';

void main() {
  final ctx = CouchdbTestContext();
  // final ctx = InMemoryTestContext();
  allDocTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> allDocTest() {
  return [
    (FoodbTestContext ctx) {
      test('allDocs include docs', () async {
        final db = await ctx.db('all-docs-include-docs');
        await db.put(doc: Doc(id: '1', model: {}));
        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true), (value) => value);
        expect(result.totalRows, 1);
        expect(result.rows, hasLength(1));
        expect(result.rows[0].doc, isNotNull);
      });
    },
    (FoodbTestContext ctx) {
      test('allDocs with corrent rebuild', () async {
        final db = await ctx.db('all-docs-with-correct-rebuild');
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
    (FoodbTestContext ctx) {
      test('all docs with keys', () async {
        final db = await ctx.db('all-docs-with-startkey-and-endkey');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, keys: ['a', 'c']),
            (value) => value);
        expect(result.totalRows, 3);
        expect(result.rows, hasLength(2));
      });
    },
    (FoodbTestContext ctx) {
      test('all docs with startkey and endkey', () async {
        final db = await ctx.db('all-docs-with-startkey-and-endkey');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'a1', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, startkey: 'a', endkey: 'a\uffff'),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(2));
      });
    },
    (FoodbTestContext ctx) {
      test('all docs with descending', () async {
        final db = await ctx.db('all-docs-with-descending');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(
                includeDocs: true,
                startkey: 'b\ufff0',
                endkey: 'b',
                descending: true),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(1));
        // TODO handle for objectbox;
        // expect(result.offset, 2);
      });
    },
    (FoodbTestContext ctx) {
      test('all docs with descending and no inclusive end', () async {
        final db = await ctx.db('all-docs-with-descending');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(
                includeDocs: true,
                startkey: 'b\ufff0',
                endkey: 'b',
                descending: true,
                inclusiveEnd: false),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(0));
        // TODO handle for objectbox;
        // expect(result.offset, 2);
      });
    },
    (FoodbTestContext ctx) {
      test('all docs with startkey only', () async {
        final db = await ctx.db('all-docs-with-startkey-only');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, startkey: 'c', descending: true),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(3));
        // TODO handle for objectbox;
        // expect(result.offset, 1);
      });
    },
    (FoodbTestContext ctx) {
      test('all docs with endkey only', () async {
        final db = await ctx.db('all-docs-with-endkey-only');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, endkey: 'c', descending: true),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(2));
        // TODO handle for objectbox;
        // expect(result.offset, 0);
      });
    },
  ];
}
