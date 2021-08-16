import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
    adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(winnerIndex: 0, docs: [
          Doc(id: 'a', model: {}, rev: '1', localSeq: '1'),
          Doc(id: 'a', model: {}, rev: '2', localSeq: '2'),
          Doc(id: 'a', model: {}, rev: '3', localSeq: '3'),
          Doc(id: 'a', model: {}, rev: '4', localSeq: '5')
        ]).toJson((value) => value));
    adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(
                winnerIndex: 0,
                docs: [Doc(id: 'b', model: {}, rev: '1', localSeq: '4')])
            .toJson((value) => value));

    adapter.db.put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    adapter.db.put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    var stream =
        await adapter.changesStream(ChangeRequest(since: '0', feed: 'normal'));
    Completer<ChangeResponse> c = new Completer();
    stream.onComplete((resp) async {
      c.complete(resp);
    });
    var response = await c.future;
    expect(response.results[0].id, 'b');
    expect(response.results[0].id, 'a');
    // limit, since work
  });

  test("allDoc", () async {
    var adapter = getMemeoryAdapter();
    adapter.db.put(adapter.docTableName,
        id: 'a',
        object: DocHistory(winnerIndex: 3, docs: [
          Doc(id: 'a', model: {}, rev: '1', localSeq: '1'),
          Doc(id: 'a', model: {}, rev: '2', localSeq: '2'),
          Doc(id: 'a', model: {}, rev: '3', localSeq: '3'),
          Doc(id: 'a', model: {}, rev: '4', localSeq: '5')
        ]).toJson((value) => value));
    adapter.db.put(adapter.docTableName,
        id: 'b',
        object: DocHistory(
                winnerIndex: 0,
                docs: [Doc(id: 'b', model: {}, rev: '1', localSeq: '4')])
            .toJson((value) => value));

    adapter.db.put(adapter.sequenceTableName, id: '4', object: {"id": 'b'});
    adapter.db.put(adapter.sequenceTableName, id: '5', object: {"id": 'a'});

    var docs = await adapter.allDocs(GetAllDocsRequest(), (json) => json);
    expect(docs.rows.length, 2);
    expect(docs.rows[0].id, 'a');
    expect(docs.rows[0].value.rev, '4');
    expect(docs.rows[0].id, 'b');
    expect(docs.rows[1].value.rev, '1');
  });
}
