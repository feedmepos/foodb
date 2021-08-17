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

    await adapter.db.put(adapter.docTableName,
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
    await adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(docs: [
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

    GetAllDocs<Map<String, dynamic>> docs =
        await adapter.allDocs(GetAllDocsRequest(), (json) => json);
    print(docs.toJson((value) => value));
    expect(docs.rows.length, equals(2));

    Map<String, Map<String, dynamic>> map =
        await adapter.db.read(adapter.viewTableName("_all_docs__all_docs"));
    print(map);
    expect(map.length, equals(2));
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

  //winner doc invalid conflict tocheck with small victor
  test("changeStream", () async {
    var adapter = getMemoryAdapter();
    await adapter.db.put(adapter.docTableName,
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
    await adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(docs: [
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
        object: DocHistory(docs: [
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
        object: DocHistory(docs: [
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
        object: DocHistory(
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
