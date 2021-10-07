import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  final couchdb = CouchdbTestContext();
  final inMemory = InMemoryTestContext();
  group('couchdb > couchbdb', () {
    replicateTest().forEach((t) {
      t(couchdb, couchdb);
    });
  });
  group('couchdb > inMemory', () {
    replicateTest().forEach((t) {
      t(couchdb, inMemory);
    });
  });
  group('inMemory > couchbdb', () {
    replicateTest().forEach((t) {
      t(inMemory, couchdb);
    });
  });
  group('inMemory > inMemory', () {
    replicateTest().forEach((t) {
      t(inMemory, inMemory);
    });
  });
}

List<Function(FoodbTestContext sourceCtx, FoodbTestContext targetCtx)>
    replicateTest() {
  return [
    (FoodbTestContext sourceCtx, FoodbTestContext targetCtx) {
      test('repliacte correct doc with revisions and deleted', () async {
        final source =
            await sourceCtx.db('replicate-source-revisions-and-deleted');
        final target =
            await targetCtx.db('replicate-target-revisions-and-deleted');

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
      test('repliacte non-continuous, max-batch-size', () async {
        final source = await sourceCtx.db('replicate-source-max-batch-size');
        final target = await targetCtx.db('replicate-target-max-batch-size');

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
          'repliacte continuous, long debouce, small maxBatchSize, will finish before debounce',
          () async {
        final source = await sourceCtx
            .db('test-replicate-source-continouse-trigger-by-maxBatchSize');
        final target = await targetCtx
            .db('test-replicate-target-continouse-trigger-by-maxBatchSize');

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
          'repliacte continuous, short debouce, large maxBatchSize, will finish after debounce',
          () async {
        final source = await sourceCtx
            .db('test-replicate-source-continuous-trigger-by-debounce');
        final target = await targetCtx
            .db('test-replicate-target-continuous-trigger-by-debounce');

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
          'continuous replication, debounce will not fire immediate if no initial change',
          () async {
        final source = await sourceCtx
            .db('test-replicate-source-tonituous-no-immediate-fire');
        final target = await targetCtx
            .db('test-replicate-target-tonituous-no-immediate-fire');
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
