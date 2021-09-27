import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';

import 'helper.dart';

void main() async {
  testEachAdapter('test-info', (ctx) {
    test('info()', () async {
      final db = ctx.db!;
      var result = await db.info();
      expect(result, isNotNull);
      expect(result.dbName, equals('test-info'));
    });
  });

  testEachAdapter('test-get', (ctx) {
    test('get()', () async {
      final db = ctx.db!;
      PutResponse putResponse = await db.put(doc: Doc(id: "test1", model: {}));
      expect(putResponse.ok, isTrue);

      Doc? doc1 = await db.get(id: 'test1', fromJsonT: (v) => {});
      expect(doc1, isNotNull);

      Doc? doc2 = await db.get(id: 'test3', fromJsonT: (v) => {});
      expect(doc2, isNull);
    });
  });

  testEachAdapter('test-get', (ctx) {
    test('delete()', () async {
      final db = ctx.db!;
      await db.put(
          doc: Doc(id: "test", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      DeleteResponse deleteResponse =
          await db.delete(id: "test", rev: Rev.fromString('1-a'));
      expect(deleteResponse.ok, true);
    });
  });

  testEachAdapter('test-find', (ctx) {
    test('find()', () async {
      final db = ctx.db!;
      await db.createIndex(indexFields: ['_id']);
      await db.put(doc: Doc(id: "user_123", model: {}));
      FindResponse<Map<String, dynamic>> findResponse =
          await db.find<Map<String, dynamic>>(
              FindRequest(selector: {
                '_id': {'\$regex': '^user'}
              }, sort: [
                {"_id": "asc"}
              ]),
              (json) => json);
      print(findResponse.docs);
      expect(findResponse.docs.length > 0, isTrue);
    });
  });

  testEachAdapter('test-explain', (ctx) {
    test('explain()', () async {
      final db = ctx.db!;
      await db.createIndex(indexFields: ['_id']);
      ExplainResponse explainResponse = await db.explain(FindRequest(selector: {
        '_id': {'\$regex': '^user'}
      }, sort: [
        {"_id": "asc"}
      ]));
      print(explainResponse.toJson());
      expect(explainResponse, isNotNull);
    });
  });

  testEachAdapter('test-ensure-full-commit', (ctx) {
    test('EnsureFullCommit In CouchDB adish', () async {
      final db = ctx.db!;
      EnsureFullCommitResponse ensureFullCommitResponse =
          await db.ensureFullCommit();
      expect(ensureFullCommitResponse.ok, isTrue);
    });
  });

  testEachAdapter('test-destroy', (ctx) {
    test('delete db', () async {
      final db = ctx.db!;
      await db.destroy();
      try {
        await db.info();
      } catch (err) {
        expectAsync0(() => expect(err, isInstanceOf<AdapterException>()))();
      }
    });
  });
}
