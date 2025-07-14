import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';

import 'foodb_objectbox_adapter_test.dart';

void main() {
  test('test-isolate-basic-read-put', () async {
    final dbName = 'test-isolate-basic-read-put';
    final mainAdapter = await getAdapter(dbName);
    var docKey = DocKey(key: 'singleDoc');
    mainAdapter.put(docKey, Map.from({'value': 0}));
    await Future.delayed(Duration(seconds: 1));
    for (var index = 0; index < 5; ++index) {
      var isolateName = 'isolate-$index';
      print('starting $isolateName');
      Isolate.run(() async {
        try {
          print('isolate-$index - started');
          var adapter = await getAdapter(dbName);

          for (var i = 0; i < 10; ++i) {
            adapter.runInSession((session) {
              print('$isolateName: read');
              var data = (adapter.get(docKey))!;
              print('$isolateName: read - done');
              data.value['value'] += 1;
              print('$isolateName: put');
              adapter.put(docKey, data.value);
              print('$isolateName: put - done');
            });
          }
        } catch (err) {
          print(err);
        }
        return;
      }, debugName: 'isolate-$index');
    }
    await Future.delayed(Duration(seconds: 5));
    var lastValue = mainAdapter.get(docKey);
    expect(lastValue!.value['value'], 50);
  });
  test('test-isolate-changes-stream', () async {
    final dbName = 'test-isolate-changes-stream';
    final mainAdapter = await getAdapter(dbName);
    await Future.delayed(Duration(seconds: 1));
    final mainFoodb = Foodb.keyvalue(
      dbName: dbName,
      keyValueDb: mainAdapter,
      isolateLeader: true,
    ) as KeyvalueFoodb;
    final reference = mainFoodb.isolateReference;
    final expectIsolate = expectAsync1((List<ChangeResult> r) {
      expect(r.length, 9);
    }, count: 3);
    for (var i = 0; i < 3; ++i) {
      final isolateName = 'isolate-$i';
      print('starting isolate $i');
      await Future.delayed(Duration(milliseconds: 300));
      Isolate.run(() async {
        // print('start $isolateName');
        final adapter = await getAdapter(dbName);
        final foodb = Foodb.keyvalue(dbName: dbName, keyValueDb: adapter)
            as KeyvalueFoodb;
        foodb.addIsolateMembership(reference);
        List<ChangeResult> results = [];
        foodb.changesStream(ChangeRequest(feed: ChangeFeed.continuous),
            onResult: (r) => results.add(r));
        await Future.delayed(Duration(seconds: 1));
        for (var docIndex = 0; docIndex < 3; ++docIndex) {
          final docId = '$isolateName-doc-$docIndex';
          // print('$docId - put');
          await foodb.put(doc: Doc(id: docId, model: {"a": 1}));
          // print('$docId - put done');
        }
        await Future.delayed(Duration(seconds: 1));
        return results;
      }, debugName: 'isolate $i')
          .then(expectIsolate);
    }
    final expectChanges = expectAsync1((d) => {}, count: 9);
    await mainFoodb.changesStream(ChangeRequest(feed: ChangeFeed.continuous),
        onResult: (changeResult) {
      print(changeResult);
      expectChanges(changeResult);
    });
    await Future.delayed(Duration(seconds: 5));
  });

  test('test-isolate-concurrent-put-and-all-docs-race-condition', () async {
    final dbName = 'test-isolate-concurrent-put-and-all-docs-race-condition';
    final mainAdapter = await getAdapter(dbName);
    var docKey = DocKey(key: 'singleDoc');
    mainAdapter.put(docKey, Map.from({'value': 0}));
    await Future.delayed(Duration(seconds: 1));

    FoodbDebug.logLevel = LOG_LEVEL.debug;

    final mainFoodb = Foodb.keyvalue(
      dbName: dbName,
      keyValueDb: mainAdapter,
      isolateLeader: true,
    ) as KeyvalueFoodb;
    final reference = mainFoodb.isolateReference;

    for (var i = 0; i < 50; ++i) {
      final isolateName = 'isolate-$i';
      print('starting isolate $i');
      Isolate.run(() async {
        // print('start $isolateName');
        final adapter = await getAdapter(dbName);
        final foodb = Foodb.keyvalue(dbName: dbName, keyValueDb: adapter)
            as KeyvalueFoodb;
        foodb.addIsolateMembership(reference);
        for (var docIndex = 0; docIndex < 50; ++docIndex) {
          final docId = '$isolateName-doc-$docIndex';
          // print('$docId - put');
          await foodb.put(doc: Doc(id: docId, model: {"a": 1}));
          // print('$docId - put done');
          final allDocs = await foodb.allDocs(GetViewRequest(), (t) => t);
          print(allDocs.rows.length);
        }
      }, debugName: 'isolate $i');
    }

    await Future.delayed(Duration(seconds: 20));
    var allDocs = await mainFoodb.allDocs(GetViewRequest(), (t) => t);
    expect(allDocs.rows.length, 2500);
  });

  // Test to validate issue https://github.com/feedmepos/foodb/issues/31
  // To reproduce the issue, replace the _flushClusterChanges to clusterChangeStreamController.sink.add;
  test('test-isolate-out-of-order-changes-stream', () async {
    final dbName = 'test-isolate-out-of-order-changes-stream';
    final mainAdapter = await getAdapter(dbName);
    await Future.delayed(Duration(seconds: 1));
    final mainFoodb = Foodb.keyvalue(
      dbName: dbName,
      keyValueDb: mainAdapter,
      isolateLeader: true,
    ) as KeyvalueFoodb;
    final reference = mainFoodb.isolateReference;
    for (var i = 0; i < 30; ++i) {
      final isolateName = 'isolate-$i';
      print('starting isolate $i');
      await Future.delayed(Duration(milliseconds: 20));
      Isolate.run(() async {
        // print('start $isolateName');
        final adapter = await getAdapter(dbName);
        final foodb = Foodb.keyvalue(dbName: dbName, keyValueDb: adapter)
            as KeyvalueFoodb;
        foodb.addIsolateMembership(reference);
        List<ChangeResult> results = [];
        foodb.changesStream(ChangeRequest(feed: ChangeFeed.continuous),
            onResult: (r) => results.add(r));
        // wait until the main stream is listening
        await Future.delayed(Duration(seconds: 1));
        for (var docIndex = 0; docIndex < 300; ++docIndex) {
          final docId = '$isolateName-doc-$docIndex';
          // print('$docId - put');
          await foodb.put(doc: Doc(id: docId, model: {"a": 1}));
          // print('$docId - put done');
        }
        await Future.delayed(Duration(seconds: 1));
      }, debugName: 'isolate $i');
    }
    num seq = 1;
    final allChangeReceive = Completer();
    final expectChanges = expectAsync1((ChangeResult d) {
      print('expecting seq: ${d.seq} - id: ${d.id}');
      expect(
        num.parse(d.seq!.split('-')[0]),
        seq,
      );
      seq++;
      if (seq == 10000) {
        allChangeReceive.complete();
      }
    }, count: 10000);

    await mainFoodb.changesStream(ChangeRequest(feed: ChangeFeed.continuous),
        onResult: expectChanges);
    for (var docIndex = 0; docIndex < 1000; ++docIndex) {
      final docId = 'main-doc-$docIndex';
      // print('$docId - put');
      await mainFoodb.put(doc: Doc(id: docId, model: {"a": 1}));
      // print('$docId - put done');
    }

    await allChangeReceive.future;

    final allSequences = mainAdapter.read(SequenceKey(),
        desc: false, inclusiveEnd: true, inclusiveStart: true);

    var expectedSeq = 1;
    for (final entry in allSequences.records.entries) {
      final key = entry.key;
      expect(
        key.key!,
        expectedSeq,
      );
      expectedSeq++;
    }
  });
}
