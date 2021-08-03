import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/common/doc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // test('allDocs()', () async {
  //   final CouchdbAdapter couchDb = getCouchDbAdapter();
  //   var result = await couchDb.allDocs(GetAllDocsRequest(includeDocs: true));
  //   print(result.totalRows);
  //   expect(result.totalRows, isNotNull);
  // });

  test('info()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    var result = await couchDb.info();
    expect(result, isNotNull);
    expect(result.dbName, equals(envDbName));
  });

  // test('put()', () async {
  //   final CouchdbAdapter couchDb = getCouchDbAdapter();
  //   PutResponse putResponse = await couchDb.put(body: {
  //     "json": {"id": 'test2', "no": 500, "name": "test2"},
  //   });

  //   expect(putResponse.ok, isTrue);
  // });

  test('get()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    Doc? doc1 =
        await couchDb.get(id: 'test1', revs: true, fromJsonT: (v) => {});
    expect(doc1 != null, isTrue);

    Doc? doc2 =
        await couchDb.get(id: 'test3', revs: true, fromJsonT: (v) => {});
    expect(doc2 != null, isFalse);
  });

  test('delete()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    Doc? doc = await couchDb.get(
        id: 'test2', revs: true, latest: true, fromJsonT: (v) => {});
    DeleteResponse deleteResponse =
        await couchDb.delete(id: "test2", rev: doc?.rev ?? '');
    expect(deleteResponse.ok, true);
  });

  // test('bulkdocs()', () async {
  //   final CouchdbAdapter couchDb = getCouchDbAdapter();
  //   List<Doc> newDocs = [];
  //   newDocs.add(Doc(
  //       id: 'test2',
  //       rev: '1-zu21xehvdaine5smjxy9htiegd4rptkm5',
  //       json: {
  //         'name': 'test test',
  //         'no': 1111,
  //       },
  //       revisions: Revisions(start: 1, ids: [
  //         'zu21xehvdaine5smjxy9htiegd4rptkm5',
  //         'zu21xehvdaine5smjxy9htiegd4rptkm5'
  //       ])));
  //   newDocs.add(Doc(
  //       id: 'test7',
  //       rev: '0-sasddsdsdfdfdsfdffdd',
  //       json: {
  //         'name': 'test test asdfgh',
  //         'no': 2212,
  //       },
  //       revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])));
  //   newDocs.add(Doc(
  //       id: 'test5',
  //       rev: '0-sasddsdsdfdfdsfdffdd',
  //       json: {
  //         'name': 'test test 5',
  //         'no': 222,
  //       },
  //       revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])));
  //   BulkDocResponse bulkDocResponse = await couchDb.bulkDocs(body: newDocs);
  //   expect(bulkDocResponse.error, isNull);
  // });

  test('createIndex()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    IndexResponse indexResponse =
        await couchDb.createIndex(indexFields: ['_id']);
    print(indexResponse.result);
    expect(indexResponse.result, isNotNull);
  });

  test('find()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    FindResponse findResponse = await couchDb.find(FindRequest(selector: {
      '_id': {'\$regex': '^test'}
    }));
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
    var dbName = "adish";
    int count = 0;
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: dbName.toString());
    await couchDb.init();
    await couchDb.put(doc: Doc(id: '1', model: {'name': 'ff'}));
    await couchDb.put(doc: Doc(id: '2', model: {'name': 'zz'}));
    var fn = expectAsync1((changeResponse) {
      expect(changeResponse, isNotNull);
    });
    couchDb
        .changesStream(ChangeRequest(
            includeDocs: true,
            feed: ChangeFeed.normal,
            since: '0',
            heartbeat: 1000))
        .then((changesStream) {
      var listener;
      changesStream.onHeartbeat(() {
        ++count;
        print('heartneat $count');
        // if (count == 5) {
        //   fn();
        // }
      });
      listener = changesStream.onResult((event) {
        print('onResult: ${event.toJson()}');
      });

      listener = changesStream.onComplete((changeResponse) {
        print('onCompleted: ${changeResponse.toJson()}');
        fn(changeResponse);
      });
    });

    await Future.delayed(Duration(seconds: 3));
    print('third put');
    await couchDb.put(doc: Doc(id: '3', model: {'name': 'zz'}));
  });
}
