import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';

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

  test('revsDiff', () async {
    final adapter = getMemoryAdapter();

    // adapter.put(doc: Doc(id: "id", model: {}), newRev: "1-a");
    // adapter.put(doc: Doc(id: "id", model: {}, rev: "1-a"), newRev: "2-b");
    // adapter.put(doc: Doc(id: "id", model: {}, rev: "2-b"), newRev: "3-c");
    // adapter.put(doc: Doc(id: "id", model: {}, rev: "3-c"), newRev: "4-d");
    adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(docs: [
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['a'], start: 1),
              rev: '1-a',
              localSeq: '1'),
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['b', 'a'], start: 2),
              rev: '2-b',
              localSeq: '2'),
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['c', 'b'], start: 3),
              rev: '3-c',
              localSeq: '3'),
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['d', 'c'], start: 4),
              rev: '4-d',
              localSeq: '5')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));

    Map<String, RevsDiff> revsDiff = await adapter.revsDiff(body: {
      "a": ["1-a", "4-c", "1-c", "4-d", "5-e"]
    });
    DocHistory<Map<String, dynamic>> docHistory = new DocHistory.fromJson(
        (await adapter.db.get(adapter.docTableName, id: "a"))!,
        (json) => json as Map<String, dynamic>);
    print(docHistory.docs.length);
    expect(docHistory.docs.length, equals(4));
    print(revsDiff["a"]!.toJson());
    expect(revsDiff["a"]!.missing.length, 3);
  });

  group('   newEdits=false', () {
    test('put with newRev but empty rev', () async {
      final memoryDb = getMemoryAdapter();
      //rev cannot be empty (different behaviour with couchdb)
      await memoryDb.put(
          doc: Doc(id: "id", model: {}), newRev: "1-a", newEdits: false);
      var result = await memoryDb.db.get(memoryDb.docTableName, id: 'id');
      var docHistory = DocHistory<Map<String, dynamic>>.fromJson(
          result!, (v) => v as Map<String, dynamic>);
      expect(docHistory.docs.first.rev, '1-a');
    });

    test('put with same rev but different newRev', () async {
      final memoryDb = getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "id", rev: "1-a", model: {}),
          newRev: "1-a",
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "id", rev: "1-a", model: {}),
          newRev: "2-b",
          newEdits: false);
      DocHistory docHistory = DocHistory<Map<String, dynamic>>.fromJson(
          (await memoryDb.db.get(memoryDb.docTableName, id: "id"))!,
          (json) => json as Map<String, dynamic>);
      //2b rev no stored inside
      for (Doc doc in docHistory.docs) {
        print(doc.rev);
      }
      expect(docHistory.docs.length, 2);
    });

    test('update with newedit =false and rev= newrev', () async {
      //change with rev = newRev // but in this situation, we will not know newrev is successor of which rev (original rev)
      //i see put function in value-adapter oso didnt consider predecessor
      final memoryDb = getMemoryAdapter();
      await memoryDb.put(
          doc: Doc(id: "id", rev: "1-a", model: {}),
          newRev: "1-a",
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "id", rev: "2-b", model: {}),
          newRev: "2-b",
          newEdits: false);
      await memoryDb.put(
          doc: Doc(id: "id", rev: "3-c", model: {}),
          newRev: "3-c",
          newEdits: false);
      DocHistory docHistory = DocHistory<Map<String, dynamic>>.fromJson(
          (await memoryDb.db.get(memoryDb.docTableName, id: "id"))!,
          (json) => json as Map<String, dynamic>);
      for (Doc doc in docHistory.docs) {
        print(doc.rev);
      }

      expect(docHistory.docs.length, equals(3));
    });
  });

  test("getWithOpenRev", () {
    // TODO, get all leaf node
  });

  test("leafdocs", () async {
    var adapter = getMemoryAdapter();
    adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(docs: [
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['a'], start: 1),
              rev: '1-a',
              localSeq: '1'),
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['b', 'a'], start: 2),
              rev: '2-b',
              localSeq: '2'),
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['c', 'b'], start: 3),
              rev: '3-c',
              localSeq: '3'),
          Doc(
              id: 'a',
              model: {},
              revisions: Revisions(ids: ['d', 'c'], start: 4),
              rev: '4-d',
              localSeq: '5')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));

    DocHistory<Map<String, dynamic>> history =
        DocHistory<Map<String, dynamic>>.fromJson(
            (await adapter.db.get(adapter.docTableName, id: 'a'))!,
            (json) => json as Map<String, dynamic>);
    print(history.winner?.toJson((value) => value));
    for (Doc doc in history.leafDocs) {
      print(doc.rev);
    }
    expect(history.winner?.rev, "4-d");
  });

  group('winner', () {
    var adapter = getMemoryAdapter();
    test("test with single leaf doc", () async {
      adapter.db.put(adapter.docTableName,
          id: 'a',
          object: DocHistory(docs: [
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['a'], start: 1),
                rev: '1-a',
                localSeq: '1'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['b', 'a'], start: 2),
                rev: '2-b',
                localSeq: '2'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['c, b'], start: 3),
                rev: '3-c',
                localSeq: '3'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['d', 'c'], start: 4),
                rev: '4-d',
                localSeq: '5')
          ]).toJson((value) => jsonDecode(jsonEncode(value))));

      DocHistory<Map<String, dynamic>> history =
          DocHistory<Map<String, dynamic>>.fromJson(
              (await adapter.db.get(adapter.docTableName, id: 'a'))!,
              (json) => json as Map<String, dynamic>);
      for (Doc<Map<String, dynamic>> doc in history.leafDocs) {
        print(doc.rev);
      }
      expect(history.leafDocs.length, 2);
      expect(history.winner?.rev, "4-d");
    });
    test('test with 3 different length leaf docs', () async {
      adapter.db.put(adapter.docTableName,
          id: 'a',
          object: DocHistory(docs: [
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['a'], start: 1),
                rev: '1-a',
                localSeq: '1'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['b', 'a'], start: 2),
                rev: '2-b',
                localSeq: '2'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['d'], start: 1),
                rev: '1-d',
                localSeq: '3'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['c'], start: 1),
                rev: '1-c',
                localSeq: '5')
          ]).toJson((value) => jsonDecode(jsonEncode(value))));

      DocHistory<Map<String, dynamic>> history =
          DocHistory<Map<String, dynamic>>.fromJson(
              (await adapter.db.get(adapter.docTableName, id: 'a'))!,
              (json) => json as Map<String, dynamic>);
      for (Doc<Map<String, dynamic>> doc in history.leafDocs) {
        print(doc.rev);
      }
      expect(history.leafDocs.length, 3);
      expect(history.winner?.rev, "2-b");
    });
    test('test with 3 same length leaf docs', () async {
      adapter.db.put(adapter.docTableName,
          id: 'a',
          object: DocHistory(docs: [
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['a'], start: 1),
                rev: '1-a',
                localSeq: '1'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['b', 'a'], start: 2),
                rev: '2-b',
                localSeq: '2'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['d', 'a'], start: 2),
                rev: '2-d',
                localSeq: '3'),
            Doc(
                id: 'a',
                model: {},
                revisions: Revisions(ids: ['c', 'a'], start: 2),
                rev: '2-c',
                localSeq: '5')
          ]).toJson((value) => jsonDecode(jsonEncode(value))));

      DocHistory<Map<String, dynamic>> history =
          DocHistory<Map<String, dynamic>>.fromJson(
              (await adapter.db.get(adapter.docTableName, id: 'a'))!,
              (json) => json as Map<String, dynamic>);
      for (Doc<Map<String, dynamic>> doc in history.leafDocs) {
        print(doc.rev);
      }

      expect(history.leafDocs.length, 3);
      expect(history.winner?.rev, "2-d");
    });
  });
  test("changeStream", () async {
    var adapter = getMemoryAdapter();

    await adapter.put(doc: Doc(id: "a", model: {"name": "a", "no": 666}));
    await adapter.put(doc: Doc(id: "b", model: {"name": "b", "no": 5555}));

    // var fn = expectAsync1((ChangeResponse result) {
    //   print(result.toJson());
    //   expect(result.results.length, equals(2));
    // });

    var fn = expectAsync2((int no, Function cancel) async {
      await cancel();
      await adapter.put(doc: Doc(id: "d", model: {"name": "n", "no": 999}));
      expect(no, equals(1));
    });

    ChangesStream stream = await adapter.changesStream(
        ChangeRequest(since: 'now', feed: ChangeFeed.continuous));

    int count = 0;

    stream.listen(
        onResult: expectAsync1((result) {
          print(result.toJson());
          ++count;
          if (count == 1) fn(count, stream.cancel);
        }, count: 1),
        onComplete: (response) {
          print(response.toJson());
          //fn(response);
        });

    adapter.put(doc: Doc(id: "e", model: {"name": "e", "no": 777}));
  });

  test('read', () async {
    var adapter = getMemoryAdapter();
    await adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(docs: [
          Doc(id: 'a', model: {}, rev: '1', localSeq: '1'),
          Doc(id: 'a', model: {}, rev: '2', localSeq: '2'),
          Doc(id: 'a', model: {}, rev: '3', localSeq: '3'),
          Doc(id: 'a', model: {}, rev: '4', localSeq: '5')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));
    await adapter.db.put(adapter.docTableName,
        id: 'b',
        object:
            DocHistory(docs: [Doc(id: 'b', model: {}, rev: '1', localSeq: '4')])
                .toJson((value) => jsonDecode(jsonEncode(value))));

    await adapter.db
        .put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    await adapter.db
        .put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    ReadResult result = await adapter.db.read(adapter.docTableName);
    print(result);
    expect(result.docs.length, equals(2));
  });
}
