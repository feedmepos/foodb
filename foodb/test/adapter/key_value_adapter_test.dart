import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  getMemeoryAdapter() {
    return KeyValueAdapter(dbName: 'test', db: InMemoryDatabase());
  }

  test("_generateView", () async {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);
    await adapter.put(doc: Doc(id: 'id', model: {"name": "charlies", "no": 1}));
    await adapter.put(doc: Doc(id: 'id2', model: {"name": "ants", "no": 2}));
    // adapter.db.put(adapter.viewMetaTableName,
    //     id: "_all_docs__all_docs", object: {"lastSeq": 0});
    await adapter.allDocs(GetAllDocsRequest(), (json) => json);

    Map<String, dynamic>? doc = await adapter.db
        .get(adapter.viewTableName("_all_docs__all_docs"), id: "id");
    print(doc.toString());
    expect(doc, isNotNull);

    Map<String, dynamic>? doc2 = await adapter.db
        .get(adapter.viewTableName("_all_docs__all_docs"), id: "id2");
    print(doc2.toString());
    expect(doc2, isNotNull);
  });

  test("_generateView2()", () async {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);
    await adapter.put(
        doc: Doc(id: 'id', model: {"name": "charlies", "no": 1}),
        newEdits: false,
        newRev: "1-aba");
    await adapter.put(
        doc: Doc(id: 'id', model: {"name": "ants", "no": 2}),
        newEdits: false,
        newRev: "1-bab");
    DocHistory<Map<String, dynamic>> history =
        DocHistory<Map<String, dynamic>>.fromJson(
            (await adapter.db.get(adapter.docTableName, id: "id"))!,
            (json) => json as Map<String, dynamic>);

    print(history.winner);
    expect(history.winner, isNotNull);
  });

  test('put & get', () async {
    final KeyValueAdapter memoryDb = getMemeoryAdapter();
    await memoryDb.put(doc: Doc(id: 'foo1', model: {'bar': 'foo'}));
    await memoryDb.put(doc: Doc(id: 'foo2', model: {'a': 'b'}));
    await memoryDb.put(
        doc: new Doc(id: 'foo2', model: {'bar': 'foo'}),
        newEdits: false,
        newRev: '2-dadadada');
    var doc1 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo1', fromJsonT: (v) => v);
    var doc2 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo2', fromJsonT: (v) => v);
    var doc3 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo3', fromJsonT: (v) => v);
    expect(doc1, isNotNull);
    expect(doc2, isNotNull);
    expect(doc3, isNull);
  });

  test("changeStream", () async {
    var adapter = getMemeoryAdapter();
    await adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(winnerIndex: 0, docs: [
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
    await adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(winnerIndex: 0, docs: [
          Doc(
              id: 'b',
              model: {},
              revisions: Revisions(ids: ['b'], start: 1),
              rev: '1-b',
              localSeq: '4')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));

    await adapter.db
        .put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    await adapter.db
        .put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    var fn = expectAsync1((ChangeResponse result) {
      print(result);
      expect(result.results.length, equals(0));
    });

    // var fn = expectAsync2((int no, Function cancel) {
    //   cancel();
    //   expect(no, equals(3));
    // });

    adapter
        .changesStream(ChangeRequest(since: 'now', feed: ChangeFeed.normal))
        .then((value) {
      int count = 0;

      value.onResult((result) {
        print(result);
        ++count;
        // if (count == 3) fn(count, value.cancel);
      });

      value.onComplete((response) {
        print(response);
        fn(response);
      });
    });

    await adapter.db.put(adapter.docTableName,
        id: 'c',
        object: DocHistory(winnerIndex: 0, docs: [
          Doc(
              id: 'c',
              model: {},
              revisions: Revisions(ids: ['e'], start: 1),
              rev: '1-e',
              localSeq: '6')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));

    await adapter.db
        .put(adapter.sequenceTableName, id: '6', object: {"id": 'c'});

    Future.delayed(Duration(seconds: 5)).then((value) async =>
        adapter.addChanges(
            seq: '6',
            id: 'c',
            history: DocHistory.fromJson(
                (await adapter.db.get(adapter.docTableName, id: 'c'))!,
                (json) => json)));

    await adapter.db.put(adapter.docTableName,
        id: 'd',
        object: DocHistory(winnerIndex: 0, docs: [
          Doc(
              id: 'd',
              model: {},
              revisions: Revisions(ids: ['f'], start: 1),
              rev: '1-f',
              localSeq: '7')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));

    await adapter.db
        .put(adapter.sequenceTableName, id: '7', object: {"id": 'd'});

    Future.delayed(Duration(seconds: 5)).then((value) async =>
        adapter.addChanges(
            seq: '7',
            id: 'd',
            history: DocHistory.fromJson(
                (await adapter.db.get(adapter.docTableName, id: 'd'))!,
                (json) => json)));

    var fn2 = expectAsync0(() {
      expect(10, 10);
    });

    Future.delayed(Duration(seconds: 10)).then((value) {
      print('done');
      fn2();
    });
  });

  test("allDocs()", () async {
    var adapter = getMemeoryAdapter();
    adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(winnerIndex: 3, docs: [
          Doc(id: 'a', model: {}, rev: '1', localSeq: '1'),
          Doc(id: 'a', model: {}, rev: '2', localSeq: '2'),
          Doc(id: 'a', model: {}, rev: '3', localSeq: '3'),
          Doc(id: 'a', model: {}, rev: '4', localSeq: '5')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));
    adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(
                winnerIndex: 0,
                docs: [Doc(id: 'b', model: {}, rev: '1', localSeq: '4')])
            .toJson((value) => jsonDecode(jsonEncode(value))));

    adapter.db.put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    adapter.db.put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    var docs = await adapter.allDocs(GetAllDocsRequest(), (json) => json);
    expect(docs.rows.length, 2);
    expect(docs.rows[0].id, 'a');
    expect(docs.rows[0].value.rev, '4');
    expect(docs.rows[0].id, 'b');
    expect(docs.rows[1].value.rev, '1');
  });

  test('read', () async {
    var adapter = getMemeoryAdapter();
    await adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(winnerIndex: 3, docs: [
          Doc(id: 'a', model: {}, rev: '1', localSeq: '1'),
          Doc(id: 'a', model: {}, rev: '2', localSeq: '2'),
          Doc(id: 'a', model: {}, rev: '3', localSeq: '3'),
          Doc(id: 'a', model: {}, rev: '4', localSeq: '5')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));
    await adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(
                winnerIndex: 0,
                docs: [Doc(id: 'b', model: {}, rev: '1', localSeq: '4')])
            .toJson((value) => jsonDecode(jsonEncode(value))));

    await adapter.db
        .put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    await adapter.db
        .put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    Map<String, dynamic> map = await adapter.db.read(adapter.docTableName);
    print(map);
    expect(map.length, equals(2));
  });
}
