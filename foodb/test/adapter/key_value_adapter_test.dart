import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/rev.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  getMemoryAdapter() {
    return KeyValueAdapter(dbName: 'test', db: InMemoryDatabase());
  }

  test("allDocs()", () async {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);

    await adapter.put(
        doc: Doc<Map<String, dynamic>>(
            id: "a", model: {"name": "a", "no": 999}));
    await adapter.put(
        doc: Doc<Map<String, dynamic>>(
            id: "b", model: {"name": "b", "no": 999}));
    await adapter.put(
        doc: Doc<Map<String, dynamic>>(
            id: "c", model: {"name": "c", "no": 999}));

    GetAllDocs<Map<String, dynamic>> docs = await adapter.allDocs(
        GetAllDocsRequest(
            // descending: true,
            startKeyDocId: "a",
            endKeyDocId: "a\ufff0"),
        (json) => json);
    print(docs.toJson((value) => value));
    expect(docs.rows.length, equals(1));
    expect(docs.offset, equals(0));
  });
  test('revsDiff', () async {
    final adapter = getMemoryAdapter();

    await adapter.db.put(adapter.docTableName,
        id: 'a',
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
        (await adapter.db.get(adapter.docTableName, id: "a"))!);

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
    var docsSize = await memoryDb.db.tableSize(memoryDb.docTableName);
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
      var result = await memoryDb.db.get(memoryDb.docTableName, id: 'id');
      var docHistory = DocHistory.fromJson(result!);
      expect(docHistory.docs.length, 1);
      expect(docHistory.leafDocs.length, 1);
    });

    test('put 2 different revision tree', () async {
      final memoryDb = getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "id", rev: Rev.fromString("1-a"), model: {}),
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "id", rev: Rev.fromString("2-b"), model: {}),
          newEdits: false);
      DocHistory docHistory = DocHistory.fromJson(
          (await memoryDb.db.get(memoryDb.docTableName, id: "id"))!);
      //2b rev no stored inside
      for (InternalDoc doc in docHistory.leafDocs) {
        print(doc.rev);
      }
      expect(docHistory.leafDocs.length, 2);
    });

    test(
        'update doc with newedit =false and revisions connecting to its ancestors',
        () async {
      final memoryDb = getMemoryAdapter();
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
          (await memoryDb.db.get(memoryDb.docTableName, id: "id"))!);

      for (InternalDoc doc in docHistory.leafDocs) {
        print(doc.rev);
      }

      expect(docHistory.docs.length, equals(3));
      expect(docHistory.leafDocs.length, equals(1));
    });

    test(
        "put 1-a. 2-a, 3-a, then put 3-a > 2-a > 1-a reivision, then put 3-a > 2-b > 1-b, should remain 3-a > 2-a > 1-a",
        () async {
      final memoryDb = getMemoryAdapter();

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
          (await memoryDb.db.get(memoryDb.docTableName, id: "a"))!);

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
          (await memoryDb.db.get(memoryDb.docTableName, id: "a"))!);

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
          (await memoryDb.db.get(memoryDb.docTableName, id: "a"))!);

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
          (await memoryDb.db.get(memoryDb.docTableName, id: "a"))!);
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
      await memoryDb.bulkDocs(body: [
        Doc(id: "a", rev: Rev.fromString("1-a"), model: {}),
        Doc(id: "b", rev: Rev.fromString("1-b"), deleted: true, model: {}),
        Doc(id: "c", model: {})
      ], newEdits: true);

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
      await memoryDb.bulkDocs(body: [
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
          (await memoryDb.db.get(memoryDb.docTableName, id: "d"))!);
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
      expect(result.results.length, equals(3));
    });

    // var fn = expectAsync2((int no, Function cancel) async {
    //   await cancel();
    //   await adapter.put(doc: Doc(id: "d", model: {"name": "n", "no": 999}));
    //   expect(no, equals(1));
    // });

    ChangesStream stream = await adapter
        .changesStream(ChangeRequest(since: '0', feed: ChangeFeed.longpoll));

    int count = 0;

    stream.listen(
        onResult: expectAsync1((result) {
          print(result.toJson());
          ++count;
          // if (count == 1) fn(count, stream.cancel);
        }, count: 3),
        onComplete: (response) {
          print(response.toJson());
          fn(response);
        });

    adapter.put(doc: Doc(id: "e", model: {"name": "e", "no": 777}));
  });
  test('read', () async {
    var adapter = getMemoryAdapter();
    await adapter.db.put(adapter.docTableName,
        id: 'a',
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
        id: 'b',
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
        .put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    await adapter.db
        .put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    ReadResult result = await adapter.db.read(adapter.docTableName);
    print(result);
    expect(result.docs.length, equals(2));
  });
}
