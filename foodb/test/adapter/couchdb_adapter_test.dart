import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodb/common/rev.dart';
import 'package:uuid/uuid.dart';

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String envDbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  getCouchDbAdapter({String? dbName}) {
    return new CouchdbAdapter(
        dbName: dbName ?? envDbName, baseUri: Uri.parse(baseUri));
  }

  setUp(() async {
    await getCouchDbAdapter().destroy();
    await getCouchDbAdapter().init();
  });

  group('bulkdocs()', () {
    test('bulkdocs() with newEdits= false', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
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
      BulkDocResponse bulkDocResponse = await couchDb.bulkDocs(body: newDocs);
      expect(bulkDocResponse.putResponses, []);
    });

    test('bulkdocs() with newEdits =true', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      var bulkdocResponse = await couchDb.bulkDocs(body: [
        new Doc<Map<String, dynamic>>(
            id: "test 1", model: {"name": "beefy", "no": 999}),
        new Doc<Map<String, dynamic>>(
            id: "test 2", model: {"name": "soda", "no": 999}),
      ], newEdits: true);

      expect(bulkdocResponse.putResponses.length, 2);
    });
  });

  test('allDocs()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    var result = await couchDb.allDocs<Map<String, dynamic>>(
        GetAllDocsRequest(includeDocs: true), (value) => value);
    print(result.toJson((value) => value));
    expect(result.totalRows, isNotNull);
  });

  test('info()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    var result = await couchDb.info();
    expect(result, isNotNull);
    expect(result.dbName, equals(envDbName));
  });

  group("put() with newEdits=False", () {
    const id = "putNewEditsisfalse";
    test('with Rev should be success put', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      PutResponse putResponse = await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString("1-bb"),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);

      expect(putResponse.ok, isTrue);
    });
    test('without Rev should catch error', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      try {
        await couchDb.put(
            doc: Doc(id: id, model: {"name": "wgg", "no": 300}),
            newEdits: false);
      } catch (err) {
        expectAsync0(() => {expect(err, isInstanceOf<AdapterException>())})();
      }
    });

    test('empty revisions, create new history', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('1-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('2-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      Doc<Map<String, dynamic>>? doc = await couchDb.get(
          id: id, fromJsonT: (val) => val, meta: true, revs: true);
      expect(doc, isNotNull);
      expect(doc!.conflicts!.length, 1);
      expect(doc.revisions!.ids.length, 1);
      couchDb.delete(id: id, rev: Rev.fromString('2-a'));
    });

    test('with revision, link to existing', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('1-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('2-a'),
              model: {"name": "wgg", "no": 300},
              revisions: Revisions(start: 2, ids: ['a', 'a'])),
          newEdits: false);
      Doc<Map<String, dynamic>>? doc = await couchDb.get(
          id: id, fromJsonT: (val) => val, meta: true, revs: true);
      expect(doc, isNotNull);
      expect(doc!.conflicts, isNull);
      expect(doc.revisions!.ids.length, 2);
      couchDb.delete(id: id, rev: Rev.fromString('2-a'));
    });

    // test('put conflicts', () async {
    //   final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: "adish");
    //   PutResponse conflictResponse = await couchDb.put(
    //       doc: Doc(
    //           id: "put u mf",
    //           model: {"name": "berry-berry", "no": 888},
    //           rev: "1-d5ea00d10b2471cdbe3420293c980282"),
    //       newEdits: false,
    //       newRev: "2-testtest2");

    //   expect(conflictResponse.ok, isTrue);
    // });
  });

  test('get()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    PutResponse putResponse =
        await couchDb.put(doc: Doc(id: "test1", model: {}));
    expect(putResponse.ok, isTrue);

    Doc? doc1 = await couchDb.get(id: 'test1', fromJsonT: (v) => {});
    expect(doc1, isNotNull);

    Doc? doc2 = await couchDb.get(id: 'test3', fromJsonT: (v) => {});
    expect(doc2, isNull);
  });

  group('designDoc', () {
    final CouchdbAdapter couchdb = getCouchDbAdapter();
    setUp(() async {
      await couchdb.createIndex(indexFields: ['_id'], ddoc: "type_user_id");
      await couchdb.createIndex(indexFields: ['name'], ddoc: "type_user_name");
    });
    test('fetchDesignDoc()', () async {
      Doc<DesignDoc>? designDoc =
          await couchdb.fetchDesignDoc(id: "_design/type_user_name");
      print(designDoc?.toJson((value) => value.toJson()));
      expect(designDoc, isNotNull);
    });

    test('fetchAllDesignDocs()', () async {
      List<Doc<DesignDoc>?> designDoc = await couchdb.fetchAllDesignDocs();
      expect(designDoc.length, equals(2));
    });
  });

  test('delete()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    await couchDb.put(
        doc: Doc(id: "test", rev: Rev.fromString("1-a"), model: {}),
        newEdits: false);
    DeleteResponse deleteResponse =
        await couchDb.delete(id: "test", rev: Rev.fromString('1-a'));
    expect(deleteResponse.ok, true);
  });

  test('createIndex()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    IndexResponse indexResponse =
        await couchDb.createIndex(indexFields: ['_id']);
    print(indexResponse.toJson());
    expect(indexResponse.result, isNotNull);
  });

  test('find()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    await couchDb.createIndex(indexFields: ['_id']);
    await couchDb.put(doc: Doc(id: "user_123", model: {}));
    FindResponse<Map<String, dynamic>> findResponse =
        await couchDb.find<Map<String, dynamic>>(
            FindRequest(selector: {
              '_id': {'\$regex': '^user'}
            }),
            (json) => json);
    print(findResponse.docs);
    expect(findResponse.docs.length > 0, isTrue);
  });

  test('EnsureFullCommit In CouchDB adish', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    EnsureFullCommitResponse ensureFullCommitResponse =
        await couchDb.ensureFullCommit();
    expect(ensureFullCommitResponse.ok, isTrue);
  });
  test('init', () async {
    var dbName = Uuid().v4();
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: dbName.toString());
    bool test = await couchDb.init();
    expect(test, true);

    bool destroy = await couchDb.destroy();
    expect(destroy, true);
  });

  test('delete db', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: "aawertyuytre");
    await couchDb.destroy();
  });

  test("change stream", () async {
    int count = 0;
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    await couchDb.put(doc: Doc(id: '1', model: {'name': 'ff'}));
    await couchDb.put(
        doc: Doc(id: '2', model: {'name': 'zz'}, rev: Rev.fromString('1-a')),
        newEdits: false);
    await couchDb.delete(id: '2', rev: Rev.fromString('1-a'));
    var fn = expectAsync1((changeResponse) {
      expect(changeResponse, isNotNull);
    });
    couchDb
        .changesStream(ChangeRequest(
            includeDocs: true,
            feed: ChangeFeed.normal,
            since: '0',
            style: "all_docs",
            heartbeat: 1000))
        .then((changesStream) {
      var listener = changesStream.listen(onHearbeat: () {
        ++count;
        print('heartneat $count');
        // if (count == 5) {
        //   fn();
        // }
      }, onResult: (event) {
        print('onResult: ${event.toJson()}');
      }, onComplete: (changeResponse) {
        print('onCompleted: ${changeResponse.toJson()}');
        fn(changeResponse);
      });
    });

    await Future.delayed(Duration(seconds: 3));
    await couchDb.put(doc: Doc(id: '3', model: {'name': 'zz'}));
  });
}
