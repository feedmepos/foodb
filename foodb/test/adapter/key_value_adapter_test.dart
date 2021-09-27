import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/rev.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['IN_MEMORY_DB_NAME'] as String;

  getMemoryAdapter() {
    // return KeyValueAdapter(dbName: dbName, db: InMemoryDatabase());
  }

  group('allDocs', () {
    var adapter = getMemoryAdapter();

    setUp(() async {
      adapter = getMemoryAdapter();
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "a",
              rev: Rev.fromString("1-a"),
              model: {"name": "a", "no": 999}),
          newEdits: false);
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "b",
              rev: Rev.fromString("1-b"),
              model: {"name": "b", "no": 999}),
          newEdits: false);
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "c",
              rev: Rev.fromString("1-c"),
              model: {"name": "c", "no": 999}),
          newEdits: false);
    });
    test("check _generateView by create a, b, c and then delete/update a, b",
        () async {
      GetAllDocsResponse<Map<String, dynamic>> docs = await adapter
          .allDocs<Map<String, dynamic>>(GetAllDocsRequest(), (json) => json);
      print(docs.toJson((value) => value));
      expect(docs.rows.length, equals(3));

      await adapter.delete(id: "a", rev: Rev.fromString("1-a"));
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "b",
              rev: Rev.fromString("1-b"),
              model: {"name": "a", "no": 999}));

      GetAllDocsResponse<Map<String, dynamic>> docsAfterChange =
          await adapter.allDocs(GetAllDocsRequest(), (json) => json);
      print(docsAfterChange.toJson((value) => value));
      expect(docsAfterChange.rows.length, equals(2));
    });

    test("check allDocs with startKey and endKey", () async {
      GetAllDocsResponse<Map<String, dynamic>> docs = await adapter.allDocs(
          GetAllDocsRequest(startkey: "a", endkey: "b\uffff"), (json) => json);
      print(docs.toJson((value) => value));
      expect(docs.rows.length, equals(2));
    });

    test("allDocs after over 100 put doc", () async {
      final adapter = getMemoryAdapter();
      List<String> list = [
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z'
      ];
      for (String i in list) {
        for (int y = 0; y < 5; y++) {
          String id2 = "$i$y";
          for (int x = 0; x < 10; x++) {
            await adapter.put(
                doc: Doc(
                    id: id2,
                    model: {"name": "wth", "no": 99},
                    rev: Rev.fromString("$y-$x")),
                newEdits: false);
          }
        }
      }

      for (int y = 0; y < 5; y++) {
        String id2 = "l$y";
        for (int x = 0; x < 10; x++) {
          await adapter.put(
              doc: Doc(
                  id: id2,
                  model: {"name": "wth", "no": 99},
                  rev: Rev.fromString("$y-$x")),
              newEdits: false);
        }
      }
      GetAllDocsResponse getAllDocs = await adapter.allDocs(
          GetAllDocsRequest(startkey: "l", endkey: "l\uffff"), (json) => json);
      expect(getAllDocs.rows.length, equals(5));
      expect(getAllDocs.totalRows, equals(130));
    });
  });
  test('revsDiff', () async {
    final adapter = getMemoryAdapter();

    await adapter.db.put(DocDataType(),
        key: 'a',
        object: DocHistory(
            id: 'a',
            docs: {
              "1-a": InternalDoc(
                  rev: Rev.fromString("1-a"),
                  deleted: false,
                  localSeq: "1",
                  data: {}),
              "2-b": InternalDoc(
                  rev: Rev.fromString("2-b"),
                  deleted: false,
                  localSeq: "2",
                  data: {}),
              "3-c": InternalDoc(
                  rev: Rev.fromString("3-c"),
                  deleted: false,
                  localSeq: "3",
                  data: {}),
              "4-d": InternalDoc(
                  rev: Rev.fromString("4-d"),
                  deleted: false,
                  localSeq: "4",
                  data: {})
            },
            revisions: RevisionTree(nodes: [
              RevisionNode(rev: Rev.fromString('1-a')),
              RevisionNode(
                  rev: Rev.fromString('2-b'), prevRev: Rev.fromString('1-a')),
              RevisionNode(
                  rev: Rev.fromString('3-c'), prevRev: Rev.fromString('2-b')),
              RevisionNode(
                  rev: Rev.fromString('4-d'), prevRev: Rev.fromString('3-c'))
            ])).toJson());

    Map<String, RevsDiff> revsDiff = await adapter.revsDiff(body: {
      "a": ["1-a", "4-c", "1-c", "4-d", "5-e"]
    });
    DocHistory docHistory = new DocHistory.fromJson(
        (await adapter.db.get(DocDataType(), key: "a"))!);

    expect(docHistory.docs.length, equals(4));

    print(revsDiff["a"]!.toJson());
    expect(revsDiff["a"]!.missing.length, 3);
  });
  test('put & get', () async {
    final memoryDb = getMemoryAdapter();
    var res1 = await memoryDb.put(doc: Doc(id: 'foo1', model: {'a': 'b'}));
    var res2 = await memoryDb.put(
        doc: Doc(id: 'foo2', model: {'c': 'd'}, rev: res1.rev));
    var res3 = await memoryDb.put(
        doc: Doc(id: 'foo3', model: {'e': 'f'}, rev: res2.rev));
    var res4 = await memoryDb.put(
        doc: Doc(id: 'foo4', model: {'e': 'f'}, rev: res3.rev));
    await memoryDb.put(doc: Doc(id: 'foo5', model: {'e': 'f'}, rev: res4.rev));
    var docsSize = await memoryDb.db.tableSize(DocDataType());
    var doc1 = await memoryDb.get(id: 'foo1', fromJsonT: (v) => v);
    var doc2 = await memoryDb.get(id: 'foo2', fromJsonT: (v) => v);
    expect(res2.ok, true);
    expect(docsSize, 5);
    expect(doc1?.model['a'], isNotNull);
    expect(doc2?.model['c'], isNotNull);
  });
  group('put with newEdits=false', () {
    test('put 1 single doc', () async {
      final memoryDb = getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "id", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      var result = await memoryDb.db.get(DocDataType(), key: 'id');
      var docHistory = DocHistory.fromJson(result!);
      expect(docHistory.docs.length, 1);
      expect(docHistory.leafDocs.length, 1);
    });

    test('put 2 different revision tree', () async {
      final memoryDb = await getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "id", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "id", rev: Rev.fromString("2-b"), model: {}),
          newEdits: false);
      DocHistory docHistory = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "id"))!);
      //2b rev no stored inside
      for (InternalDoc doc in docHistory.leafDocs) {
        print(doc.rev);
      }
      expect(docHistory.leafDocs.length, 2);
    });

    test(
        'update doc with newedit =false and revisions connecting to its ancestors',
        () async {
      final memoryDb = await getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "id", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(
              id: "id",
              rev: Rev.fromString("2-b"),
              model: {},
              revisions: Revisions(ids: ['b', 'a'], start: 2)),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(
              id: "id",
              rev: Rev.fromString("3-c"),
              model: {},
              revisions: Revisions(ids: ['c', 'b'], start: 3)),
          newEdits: false);

      DocHistory docHistory = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "id"))!);

      for (InternalDoc doc in docHistory.leafDocs) {
        print(doc.rev);
      }

      expect(docHistory.docs.length, equals(3));
      expect(docHistory.leafDocs.length, equals(1));
    });

    test(
        "put 1-a. 2-a, 3-a, then put 3-a > 2-a > 1-a reivision, then put 3-a > 2-b > 1-b, should remain 3-a > 2-a > 1-a",
        () async {
      final memoryDb = await getMemoryAdapter();

      await memoryDb.put(
          doc: Doc(id: "a", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "a", rev: Rev.fromString("2-a"), model: {}),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "a", rev: Rev.fromString("3-a"), model: {}),
          newEdits: false);

      DocHistory history = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "a"))!);

      expect(history.leafDocs.length, equals(3));
      expect(history.docs.length, equals(3));

      await memoryDb.put(
          doc: Doc(
              id: "a",
              rev: Rev.fromString("3-a"),
              model: {},
              revisions: Revisions(ids: ['a', 'a', 'a'], start: 3)),
          newEdits: false);

      DocHistory historyAfterRevChg = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "a"))!);

      expect(historyAfterRevChg.leafDocs.length, equals(1));
      expect(historyAfterRevChg.docs.length, equals(3));

      await memoryDb.put(
          doc: Doc(id: "a", rev: Rev.fromString("1-b"), model: {}),
          newEdits: false);

      await memoryDb.put(
          doc: Doc(
              id: "a",
              rev: Rev.fromString("2-b"),
              model: {},
              revisions: Revisions(ids: ['b', 'b'], start: 3)),
          newEdits: false);

      await memoryDb.put(
          doc: Doc(
              id: "a",
              rev: Rev.fromString("3-a"),
              model: {},
              revisions: Revisions(ids: ['a', 'b', 'b'], start: 3)),
          newEdits: false);

      DocHistory historyAfterSecChg = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "a"))!);

      RevisionNode currNode = historyAfterSecChg.revisions.nodes
          .where((element) => element.rev == Rev.fromString("3-a"))
          .toList()[0];

      expect(currNode.prevRev, equals(Rev.fromString("2-a")));

      RevisionNode prevNode = historyAfterSecChg.revisions.nodes
          .where((element) => element.rev == currNode.prevRev)
          .toList()[0];

      expect(prevNode.prevRev, equals(Rev.fromString("1-a")));
    });
  });
  group('put with newEdits=true', () {
    test('put new doc', () async {
      final memoryDb = getMemoryAdapter();
      await memoryDb.put(doc: Doc(id: "a", model: {}));
      Doc<Map<String, dynamic>>? doc =
          await memoryDb.get(id: "a", fromJsonT: (value) => value);
      expect(doc, isNotNull);
    });

    test('update doc', () async {
      final memoryDb = getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "a", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "a", rev: Rev.fromString("1-a"), model: {}));

      DocHistory history = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "a"))!);
      expect(history.leafDocs.length, 1);
      expect(history.docs.length, 2);
      expect(history.winner?.rev, isNot(Rev.fromString("1-a")));
    });
  });
  group('delete', () {
    final memoryDb = getMemoryAdapter();
    setUp(() async {
      await memoryDb.put(
          doc: Doc(id: "a", model: {}, rev: Rev.fromString("1-a")),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(
              id: "a",
              model: {},
              rev: Rev.fromString("2-b"),
              revisions: Revisions(ids: ["b", "a"], start: 2)),
          newEdits: false);
    });
    test('delete leafdoc', () async {
      DeleteResponse deleteResponse =
          await memoryDb.delete(id: "a", rev: Rev.fromString("2-b"));
      expect(deleteResponse.ok, true);

      Doc<Map<String, dynamic>>? doc = await memoryDb.get<Map<String, dynamic>>(
          id: "a", fromJsonT: (value) => value);
      expect(doc, isNull);
    });
    test('delete non-leafdoc, should throw error', () async {
      try {
        DeleteResponse deleteResponse =
            await memoryDb.delete(id: "a", rev: Rev.fromString("1-a"));
        expect(deleteResponse.ok, true);

        Doc<Map<String, dynamic>>? doc = await memoryDb
            .get<Map<String, dynamic>>(id: "a", fromJsonT: (value) => value);
      } catch (e) {
        expect(e, isInstanceOf<AdapterException>());
      }
    });

    test("delete doc with 2 leaf nodes", () async {
      await memoryDb.put(
          doc: Doc(
              id: "a",
              rev: Rev.fromString("2-c"),
              revisions: Revisions(ids: ['c', 'a'], start: 2),
              model: {}),
          newEdits: false);
      DocHistory history = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "a"))!);
      expect(history.leafDocs.length, 2);

      await memoryDb.delete(id: "a", rev: Rev.fromString("2-c"));
      DocHistory historyAfterDelete = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "a"))!);
      print(historyAfterDelete.winner?.rev.toString());
      expect(historyAfterDelete.leafDocs.length, 2);
    });
  });
  group('bulkdocs', () {
    final memoryDb = getMemoryAdapter();

    setUp(() async {
      await memoryDb.put(
          doc: Doc(id: "a", model: {}, rev: Rev.fromString("1-a")),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "b", model: {}, rev: Rev.fromString("1-b")),
          newEdits: false);
    });
    test('bulkdocs with newEdits =true', () async {
      BulkDocResponse bulkDocsResponse = await memoryDb.bulkDocs(body: [
        Doc(id: "a", rev: Rev.fromString("1-a"), model: {}),
        Doc(id: "b", rev: Rev.fromString("1-b"), deleted: true, model: {}),
        Doc(id: "c", model: {})
      ], newEdits: true);

      expect(bulkDocsResponse.putResponses[0].ok, true);
      expect(bulkDocsResponse.putResponses[1].ok, true);
      expect(bulkDocsResponse.putResponses[2].ok, true);

      Doc<Map<String, dynamic>>? doc1 =
          await memoryDb.get(id: "a", fromJsonT: (value) => value);
      expect(doc1?.rev?.index, 2);

      Doc<Map<String, dynamic>>? doc2 =
          await memoryDb.get(id: "b", fromJsonT: (value) => value);
      expect(doc2, isNull);

      Doc<Map<String, dynamic>>? doc3 =
          await memoryDb.get(id: "c", fromJsonT: (value) => value);
      expect(doc3, isNotNull);
    });

    test('bulkdocs with newEdits = false', () async {
      BulkDocResponse bulkDocsResponse = await memoryDb.bulkDocs(body: [
        Doc(
            id: "a",
            rev: Rev.fromString("2-a"),
            model: {},
            revisions: Revisions(ids: ['a', 'a'], start: 2)),
        Doc(
            id: "b",
            rev: Rev.fromString("2-b"),
            deleted: true,
            model: {},
            revisions: Revisions(ids: ['b', 'b'], start: 2)),
        Doc(id: "c", rev: Rev.fromString("1-c"), model: {}),
        Doc(
            id: "d",
            rev: Rev.fromString("3-d"),
            model: {},
            revisions: Revisions(ids: ['d', 'c'], start: 3))
      ], newEdits: false);

      expect(bulkDocsResponse.putResponses[0].ok, true);
      expect(bulkDocsResponse.putResponses[1].ok, true);
      expect(bulkDocsResponse.putResponses[2].ok, true);

      Doc<Map<String, dynamic>>? doc1 =
          await memoryDb.get(id: "a", fromJsonT: (value) => value);
      expect(doc1?.rev?.index, 2);

      Doc<Map<String, dynamic>>? doc2 =
          await memoryDb.get(id: "b", fromJsonT: (value) => value);
      expect(doc2, isNull);

      Doc<Map<String, dynamic>>? doc3 =
          await memoryDb.get(id: "c", fromJsonT: (value) => value);
      expect(doc3, isNotNull);

      Doc<Map<String, dynamic>>? doc4 =
          await memoryDb.get(id: "d", fromJsonT: (value) => value);
      expect(doc4?.rev.toString(), "3-d");

      DocHistory history = DocHistory.fromJson(
          (await memoryDb.db.get(DocDataType(), key: "d"))!);
      expect(history.leafDocs.length, 1);
      expect(history.docs.length, 1);
    });
  });
  test("getWithOpenRev", () {
    // TODO, get all leaf node
  });
  test("changeStream", () async {
    var adapter = getMemoryAdapter();

    await adapter.put(doc: Doc(id: "a", model: {"name": "a", "no": 666}));
    await adapter.put(doc: Doc(id: "b", model: {"name": "b", "no": 5555}));

    var fn = expectAsync1((ChangeResponse result) {
      print(result.toJson());
      expect(result.results.length, equals(2));
    });

    // var fn = expectAsync2((int no, Function cancel) async {
    //   await cancel();
    //   await adapter.put(doc: Doc(id: "d", model: {"name": "n", "no": 999}));
    //   expect(no, equals(1));
    // });

    ChangesStream stream = await adapter
        .changesStream(ChangeRequest(since: '0', feed: ChangeFeed.normal));

    int count = 0;

    stream.listen(
        onResult: expectAsync1((result) {
          print(result.toJson());
          ++count;
          // if (count == 1) fn(count, stream.cancel);
        }, count: 2),
        onComplete: (response) {
          print(response.toJson());
          fn(response);
        });

    Future.delayed(Duration(seconds: 5)).then((value) =>
        adapter.put(doc: Doc(id: "e", model: {"name": "e", "no": 777})));
  });

    test("changeStream", () async {
    var adapter = getMemoryAdapter();

    await adapter.put(doc: Doc(id: "a", model: {"name": "a", "no": 666}));
    await adapter.put(doc: Doc(id: "b", model: {"name": "b", "no": 5555}));

    var fn = expectAsync1((ChangeResponse result) {
      print(result.toJson());
      expect(result.results.length, equals(2));
    });

    // var fn = expectAsync2((int no, Function cancel) async {
    //   await cancel();
    //   await adapter.put(doc: Doc(id: "d", model: {"name": "n", "no": 999}));
    //   expect(no, equals(1));
    // });

    ChangesStream stream = await adapter
        .changesStream(ChangeRequest(since: '0', feed: ChangeFeed.normal));

    int count = 0;

    stream.listen(
        onResult: expectAsync1((result) {
          print(result.toJson());
          ++count;
          // if (count == 1) fn(count, stream.cancel);
        }, count: 2),
        onComplete: (response) {
          print(response.toJson());
          fn(response);
        });

    Future.delayed(Duration(seconds: 5)).then((value) =>
        adapter.put(doc: Doc(id: "e", model: {"name": "e", "no": 777})));
  });
  test('read', () async {
    var adapter = getMemoryAdapter();
    await adapter.db.put(DocDataType(),
        key: 'a',
        object: DocHistory(
            id: 'a',
            docs: {
              "1-a": InternalDoc(
                  rev: Rev.fromString("1-a"),
                  deleted: false,
                  localSeq: "1",
                  data: {}),
              "2-b": InternalDoc(
                  rev: Rev.fromString("2-b"),
                  deleted: false,
                  localSeq: "2",
                  data: {}),
              "3-c": InternalDoc(
                  rev: Rev.fromString("3-c"),
                  deleted: false,
                  localSeq: "3",
                  data: {}),
              "4-d": InternalDoc(
                  rev: Rev.fromString("4-d"),
                  deleted: false,
                  localSeq: "5",
                  data: {})
            },
            revisions: RevisionTree(nodes: [
              RevisionNode(rev: Rev.fromString('1-a')),
              RevisionNode(
                  rev: Rev.fromString('2-b'), prevRev: Rev.fromString('1-a')),
              RevisionNode(
                  rev: Rev.fromString('3-c'), prevRev: Rev.fromString('2-b')),
              RevisionNode(
                  rev: Rev.fromString('4-d'), prevRev: Rev.fromString('3-c'))
            ])).toJson());
    ;
    await adapter.db.put(adapter.docTableName,
        key: 'b',
        object: DocHistory(
            id: 'b',
            docs: {
              "1-a": InternalDoc(
                  rev: Rev.fromString("1-a"),
                  deleted: false,
                  localSeq: "4",
                  data: {}),
            },
            revisions: RevisionTree(
                nodes: [RevisionNode(rev: Rev.fromString('1-a'))])).toJson());

    await adapter.db
        .put(adapter.sequenceTableName, key: '4', object: {"id": 'b'});
    await adapter.db
        .put(adapter.sequenceTableName, key: '5', object: {"id": 'a'});

    ReadResult result = await adapter.db.read(adapter.docTableName);
    print(result);
    expect(result.docs.length, equals(2));
  });
  group("createIndex", () {
    final memoryDb = getMemoryAdapter();
    test('create with indexFields only', () async {
      IndexResponse indexResponse =
          await memoryDb.createIndex(indexFields: ["_id"]);
      expect(indexResponse, isNotNull);

      Doc<Map<String, dynamic>>? doc =
          await memoryDb.get(id: indexResponse.id, fromJsonT: (json) => json);
      print(doc?.toJson((value) => value));
      expect(doc, isNotNull);
    });

    test('create with indexFields and partial_filter_selector', () async {
      IndexResponse indexResponse = await memoryDb.createIndex(
        indexFields: ["_id"],
        partialFilterSelector: {
          "year": {"\$gt": 2010},
        },
      );
      expect(indexResponse, isNotNull);

      Doc<Map<String, dynamic>>? doc =
          await memoryDb.get(id: indexResponse.id, fromJsonT: (json) => json);
      print(doc?.toJson((value) => value));
      expect(doc, isNotNull);

      Doc<DesignDoc>? doc2 = await memoryDb.get(
          id: indexResponse.id, fromJsonT: (json) => DesignDoc.fromJson(json));
      print(doc2?.toJson((value) => value.toJson()));
      expect(doc2, isNotNull);
    });

    test('update design doc with new view', () async {
      IndexResponse indexResponse = await memoryDb.createIndex(
        indexFields: ["_id"],
        ddoc: "_design/a",
        partialFilterSelector: {
          "year": {"\$gt": 2010},
        },
      );
      expect(indexResponse, isNotNull);

      Doc<Map<String, dynamic>>? doc =
          await memoryDb.get(id: indexResponse.id, fromJsonT: (json) => json);
      print(doc?.toJson((value) => value));
      expect(doc, isNotNull);

      IndexResponse indexResponse2 = await memoryDb.createIndex(
        indexFields: ["_id"],
        ddoc: "_design/a",
        partialFilterSelector: {
          "year": {"\$gt": 2010},
        },
      );
      expect(indexResponse2, isNotNull);

      Doc<DesignDoc>? docAfterUpdate = await memoryDb.get(
          id: indexResponse2.id, fromJsonT: (json) => DesignDoc.fromJson(json));
      print(docAfterUpdate?.toJson((value) => value.toJson()));
      expect(docAfterUpdate, isNotNull);
      expect(docAfterUpdate?.model.views.length, 2);
    });
  });

  String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  test("view", () async {
    final memoryDb = getMemoryAdapter();
    await memoryDb.put(doc: Doc(id: "a", model: {"name": "a", "no": 99}));
    await memoryDb.put(doc: Doc(id: "b", model: {"name": "b", "no": 77}));

    //"-" is not allowed as index name
    IndexResponse indexResponse = await memoryDb.createIndex(
        indexFields: ["name", "no"], ddoc: "name_view", name: "name_index");
    expect(indexResponse, isNotNull);

    Doc<Map<String, dynamic>>? doc =
        await memoryDb.get(id: indexResponse.id, fromJsonT: (json) => json);
    print(doc?.toJson((value) => value));
    expect(doc, isNotNull);

    List<AllDocRow<Map<String, dynamic>>> result = await memoryDb.view(
        "name_view", "name_index",
        startKey: "_a_99",
        endKey: "_a_99\uffff",
        startKeyDocId: "a",
        endKeyDocId: "a\uffff");

    await memoryDb.put(doc: Doc(id: "c", model: {"name": "c", "no": 55}));

    List<AllDocRow<Map<String, dynamic>>> result2 = await memoryDb.view(
        "name_view", "name_index",
        startKey: "_a_99",
        endKey: "_a_99\uffff",
        startKeyDocId: "a",
        endKeyDocId: "a\uffff");

    expect(result.length, equals(1));
    expect(result2.length, equals(1));
  });
}
