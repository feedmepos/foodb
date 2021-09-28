import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/replicate.dart';

import 'adapter/adapter_test.dart';

void main() {
  final couchdb = CouchdbAdapterTestContext();
  final inMemory = InMemoryAdapterTestContext();
  replicateTest().forEach((t) {
    t(couchdb, couchdb);
  });
  replicateTest().forEach((t) {
    t(couchdb, inMemory);
  });
  replicateTest().forEach((t) {
    t(inMemory, couchdb);
  });
  replicateTest().forEach((t) {
    t(inMemory, inMemory);
  });
}

List<Function(AdapterTestContext sourceCtx, AdapterTestContext targetCtx)>
    replicateTest() {
  return [
    (AdapterTestContext sourceCtx, AdapterTestContext targetCtx) {
      String fromType = sourceCtx.runtimeType.toString();
      String toType = targetCtx.runtimeType.toString();
      test(
          '($fromType, $toType) repliacte correct doc with revisions and deleted',
          () async {
        final source = await sourceCtx.db('test-replicate-source-1');
        final target = await targetCtx.db('test-replicate-target-1');

        var complete = expectAsync0(() => {});

        await source.put(
            doc: Doc(
                id: 'a',
                rev: Rev.fromString('2-b'),
                deleted: true,
                model: {},
                revisions: Revisions(start: 2, ids: ['b', 'a'])),
            newEdits: false);

        final stream = await replicate(source, target);
        stream.listen(onComplete: (result) async {
          print(result);
          var doc =
              await target.get(id: 'a', fromJsonT: (json) => json, revs: true);
          expect(doc, isNull);
          doc = await target.get(
              id: 'a', fromJsonT: (json) => json, rev: '2-b', revs: true);
          expect(doc, isNotNull);
          expect(doc!.rev, Rev.fromString('2-b'));
          expect(doc.revisions!.start, 2);
          expect(doc.revisions!.ids, hasLength(2));
          complete();
        });
      });
      test('($fromType, $toType) repliacte non-continuous, max-batch-size',
          () async {
        final source = await sourceCtx.db('test-replicate-source-2');
        final target = await targetCtx.db('test-replicate-target-2');

        var complete = expectAsync0(() => {});
        var checkpoint = expectAsync0(() => {}, count: 2);

        await source.bulkDocs(
            body: List.generate(30, (index) => Doc(id: '$index', model: {})));

        final stream = await replicate(source, target, maxBatchSize: 29);
        stream.listen(onCheckpoint: (_) async {
          checkpoint();
        }, onComplete: (_) async {
          var docs = await target.allDocs(GetViewRequest(), (json) => json);
          expect(docs.rows, hasLength(30));
          complete();
        });
      });
      test(
          '($fromType, $toType) repliacte continuous, long debouce, small maxBatchSize, will finish before debounce',
          () async {
        final source = await sourceCtx.db('test-replicate-source-3');
        final target = await targetCtx.db('test-replicate-target-3');

        var complete = expectAsync0(() => {});
        var processedCnt = 0;
        var stopwatch = Stopwatch();
        stopwatch.start();

        final stream = await replicate(source, target,
            continuous: true,
            maxBatchSize: 10,
            debounce: Duration(seconds: 10));
        stream.listen(
          onCheckpoint: (checkpoint) async {
            processedCnt += checkpoint.processed.length;
            if (processedCnt == 30) {
              expect(stopwatch.elapsed.inSeconds, lessThan(10));
              stream.abort();
              complete();
            }
          },
        );
        Future.delayed(Duration(seconds: 1), () {
          source.bulkDocs(
              body: List.generate(30, (index) => Doc(id: '$index', model: {})));
        });
      });
      test(
          '($fromType, $toType) repliacte continuous, short debouce, large maxBatchSize, will finish after debounce',
          () async {
        final source = await sourceCtx.db('test-replicate-source-4');
        final target = await targetCtx.db('test-replicate-target-4');

        var complete = expectAsync0(() => {});
        var processedCnt = 0;
        var stopwatch = Stopwatch();
        stopwatch.start();

        final stream = await replicate(source, target,
            continuous: true, maxBatchSize: 50, debounce: Duration(seconds: 5));
        stream.listen(
          onCheckpoint: (checkpoint) async {
            processedCnt += checkpoint.processed.length;
            if (processedCnt == 30) {
              expect(stopwatch.elapsed.inSeconds, greaterThan(5));
              stream.abort();
              complete();
            }
          },
        );
        Future.delayed(Duration(seconds: 1), () {
          source.bulkDocs(
              body: List.generate(30, (index) => Doc(id: '$index', model: {})));
        });
      });
      test(
          '($fromType, $toType) continuous replication, debounce will not fire immediate if no initial change',
          () async {
        final source = await sourceCtx.db('test-replicate-source-5');
        final target = await targetCtx.db('test-replicate-target-5');
        var complete = expectAsync0(() => {});
        var checkpoint = expectAsync0(() => {}, count: 1);
        await source.put(doc: Doc(id: 'a', model: {}));
        final stream = await replicate(source, target,
            continuous: true, debounce: Duration(microseconds: 2000));
        stream.listen(onCheckpoint: (event) async {
          checkpoint();
          var doc = await target.get(id: 'a', fromJsonT: (json) => json);
          expect(doc, isNotNull);
          stream.abort();
          complete();
        });
        Future.delayed(Duration(seconds: 1),
            () => source.put(doc: Doc(id: 'b', model: {})));
      });
    }
  ];
}
