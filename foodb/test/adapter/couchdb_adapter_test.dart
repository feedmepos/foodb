import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  getCouchDbAdapter() {
    return new CouchdbAdapter(dbName: dbName, baseUri: Uri.parse(baseUri));
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
    expect(result.dbName, equals(dbName));
  });

  test('put()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    PutResponse putResponse = await couchDb.put(id: 'test2', body: {
      "json": {"no": 500, "name": "test2"},
    });

    expect(putResponse.ok, isTrue);
  });

  test('get()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    Doc? doc1 = await couchDb.get(id: 'test1', revs: true);
    expect(doc1 != null, isTrue);

    Doc? doc2 = await couchDb.get(id: 'test3', revs: true);
    expect(doc2 != null, isFalse);
  });

  test('delete()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    Doc? doc = await couchDb.get(id: 'test2', revs: true, latest: true);
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

  test('Changes Stream In CouchDB adish', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    Stream<ChangeResponse> changesStream = await couchDb
        .changesStream(ChangeRequest(includeDocs: true, feed: 'longpoll'));

    String? changes;
    StreamSubscription streamSubscription = changesStream.listen((event) {
      changes = event.results[0].id;
    }, onDone: () {
      print('done');
    }, onError: (e) {
      print('$e failed to listen');
    });
    if (changes != null) {
      streamSubscription.cancel();
    }

    expect(changes, isNotNull);
  });
}
