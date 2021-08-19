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

  getMemoryAdapter() {
    return KeyValueAdapter(dbName: 'test', db: InMemoryDatabase());
  }

  test("_generateView", () async {
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

    Map<String, dynamic> map =
        await adapter.db.read(adapter.viewTableName("_all_docs__all_docs"));
    // print(map);
    // expect(map['docs'].length, equals(2));
  });

  test('put & get', () async {
    final memoryDb = getMemoryAdapter();
    var res1 = await memoryDb.put(doc: Doc(id: 'foo1', model: {'a': 'b'}));
    var res2 = await memoryDb.put(
        doc: Doc(id: 'foo1', model: {'c': 'd'}, rev: res1.rev));
    await memoryDb.put(doc: Doc(id: 'foo1', model: {'e': 'f'}, rev: res2.rev));
    // await memoryDb.put(doc: Doc(id: 'foo1', model: {"hello": "world"}));
    await memoryDb.put(doc: Doc(id: 'foo3', model: {'a': 'b'}));
    await memoryDb.put(doc: Doc(id: 'foo4', model: {'a': 'b'}));
    await memoryDb.put(doc: Doc(id: 'foo5', model: {'a': 'b'}));
    print(await memoryDb.db.tableSize(memoryDb.docTableName));
    var docHistory = await memoryDb.getHistory('foo1');
    docHistory?.leafDocs.forEach((element) {
      print(element.toJson((value) => value));
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

  test("allDocs()", () async {
    var adapter = getMemoryAdapter();
    adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(docs: [
          Doc(id: 'a', model: {}, rev: '1', localSeq: '1'),
          Doc(id: 'a', model: {}, rev: '2', localSeq: '2'),
          Doc(id: 'a', model: {}, rev: '3', localSeq: '3'),
          Doc(id: 'a', model: {}, rev: '4', localSeq: '5')
        ]).toJson((value) => jsonDecode(jsonEncode(value))));
    adapter.db.put(adapter.docTableName,
        id: 'b',
        object:
            DocHistory(docs: [Doc(id: 'b', model: {}, rev: '1', localSeq: '4')])
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

    Map<String, dynamic> map = await adapter.db.read(adapter.docTableName);
    print(map);
    expect(map.length, equals(2));
  });
}
