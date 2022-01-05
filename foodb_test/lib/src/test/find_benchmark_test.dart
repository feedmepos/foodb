import 'dart:async';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() async {
  // findBenchmarkTest(10000, InMemoryTestContext());
  // findBenchmarkTest(10000, CouchdbTestContext());
  FoodbDebug.logLevel = LOG_LEVEL.debug;
  findProductionTest(CouchdbTestContext(), InMemoryTestContext());
}

void findBenchmarkTest(int size, FoodbTestContext targetCtx) async {
  test('find benchmark test', () async {
    final db = await targetCtx.db('find-$size');

    var docs = <Doc<Map<String, dynamic>>>[];
    for (var x = 0; x < size; x++) {
      docs.add(Doc(id: '$x', model: {'no': x}));
    }
    await db.bulkDocs(body: docs, newEdits: true);

    var allDocStopWatch = Stopwatch()..start();
    var response = await db.find(
        FindRequest(
            selector: GreaterThanOperator(key: 'no', expected: size - 101)),
        (value) => value);
    allDocStopWatch.stop();

    print('all_docs in seconds: ${allDocStopWatch.elapsed.inSeconds}');
    print(
        'all_docs perDoc: ${allDocStopWatch.elapsed.inMilliseconds / (size * 1000)}');
    expect(response.docs.length, equals(100));

    await db.createIndex(
        name: 'no-index', index: QueryViewOptionsDef(fields: ['no']));

    var designDocStopWatch = Stopwatch()..start();
    var responseAfterIndex = await db.find(
        FindRequest(
            selector: GreaterThanOperator(key: 'no', expected: size - 101)),
        (value) => value);
    designDocStopWatch.stop();

    print('design_docs in seconds: ${designDocStopWatch.elapsed.inSeconds}');
    print(
        'design_docs perDoc: ${designDocStopWatch.elapsed.inMilliseconds / (size * 1000)}');
    expect(responseAfterIndex.docs.length, equals(100));

    var designDocStopWatch2 = Stopwatch()..start();
    var responseAfterIndex2 = await db.find(
        FindRequest(
            selector: GreaterThanOperator(key: 'no', expected: size - 101)),
        (value) => value);

    designDocStopWatch2.stop();
    print('design_docs 2 in seconds: ${designDocStopWatch2.elapsed.inSeconds}');
    print(
        'design_docs 2 perDoc: ${designDocStopWatch2.elapsed.inMilliseconds / (size * 1000)}');
    expect(responseAfterIndex2.docs.length, equals(100));
  }, timeout: Timeout(Duration(minutes: 10)));
}

void findProductionTest(
    FoodbTestContext sourceCtx, FoodbTestContext targetCtx) {
  test('find benchmark test real data', () async {
    final source = await sourceCtx.db('find-production', persist: true);
    final target = await targetCtx.db('find-production', persist: true);
    final firstSync = new Completer();
    replicate(source, target, onComplete: firstSync.complete);
    await firstSync.future;

    await FoodbDebug.timed('first find', () async {
      await target.find(
          FindRequest(
              selector: EqualOperator(key: 'status', expected: 'DRAFT')),
          (json) => json);
    });

    await FoodbDebug.timed('second first find', () async {
      await target.find(
          FindRequest(
              selector: EqualOperator(key: 'status', expected: 'DRAFT')),
          (json) => json);
    });
  });
}
