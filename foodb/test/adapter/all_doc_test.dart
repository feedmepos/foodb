import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  final ctx = CouchdbAdapterTestContext();
  // final ctx = InMemoryAdapterTestContext();
  allDocTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> allDocTest() {
  return [
    (AdapterTestContext ctx) {
      test("allDocs with corrent rebuild", () async {
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
      test("all docs", () async {
        final db = await ctx.db('test-all-docs');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, startkey: 'a', endkey: 'a\uffff'),
            (value) => value);
        expect(result.totalRows, 3);
        expect(result.rows, hasLength(1));
      });
    },
    (AdapterTestContext ctx) {
      test("all docs with descending", () async {
        final db = await ctx.db('test-all-docs-with-descending');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(
                includeDocs: true,
                startkey: 'b\uffff',
                endkey: 'b',
                descending: true),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(1));
        expect(result.offset, 2);
      });
    },
    (AdapterTestContext ctx) {
      test("all docs with startkey only", () async {
        final db = await ctx.db('test-all-docs-with-startkey-only');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, startkey: 'c', descending: true),
            (value) => value);
        print(result.toJson((value) => value));
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(3));
        expect(result.offset, 1);
      });
    },
    (AdapterTestContext ctx) {
      test("all docs with endkey only", () async {
        final db = await ctx.db('test-all-docs-with-endkey-only');
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        await db.put(doc: Doc(id: 'c', model: {}));
        await db.put(doc: Doc(id: 'e', model: {}));

        var result = await db.allDocs<Map<String, dynamic>>(
            GetViewRequest(includeDocs: true, endkey: 'c', descending: true),
            (value) => value);
        expect(result.totalRows, 4);
        expect(result.rows, hasLength(2));
        expect(result.offset, 0);
      });
    },
  ];
}
