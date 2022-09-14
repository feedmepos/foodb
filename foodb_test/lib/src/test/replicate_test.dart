@Timeout(Duration(seconds: 1000))
import 'dart:async';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  final couchdb = CouchdbTestContext();
  // final ctx = InMemoryTestContext();
  final ctx = HttpServerCouchdbTestContext();
  // final ctx = WebSocketServerCouchdbTestContext();
  // group('couchdb > couchbdb', () {
  //   replicateTest().forEach((t) {
  //     t(couchdb, couchdb);
  //   });
  // });
  // group('couchdb > inMemory', () {
  replicateTest().forEach((t) {
    t(couchdb, ctx);
  });
  // });
  // group('inMemory > couchbdb', () {
  //   replicateTest().forEach((t) {
  //     t(inMemory, couchdb);
  //   });
  // });
  // group('inMemory > inMemory', () {
  //   replicateTest().forEach((t) {
  //     t(inMemory, inMemory);
  //   });
  // });

  // replicateTest().forEach((t) {
  //   t(couchdb, couchdb);
  // });
}

handleTestReplicationError(p0, stackTrace) {
  if (p0 is Exception) {
    throw p0;
  }
  throw Exception('replication error: $p0, $stackTrace');
}

List<Function(FoodbTestContext sourceCtx, FoodbTestContext targetCtx)>
    replicateTest() {
  return [
    (FoodbTestContext sourceCtx, FoodbTestContext targetCtx) {
      test('replication with compaction and rev limit', () async {
        final source = await sourceCtx.db('source-compact');
        final target = await targetCtx.db('target-compact');
        onetimeReplicate([reverse = false]) async {
          var replication = Completer();
          if (reverse)
            replicate(target, source, onComplete: replication.complete);
          else
            replicate(source, target, onComplete: replication.complete);
          await replication.future;
        }

        putDoc(Foodb db, List<String> revs) {
          var revisions = Revisions(
            start: int.parse(revs[0].split('-')[0]),
            ids: revs.map((e) => e.split('-')[1]).toList(),
          );
          var rev = Rev.fromString(revs[0]);
          return db.put(
              doc: Doc(
                id: 'a',
                rev: rev,
                model: {},
                revisions: revisions,
              ),
              newEdits: false);
        }

        getDoc(Foodb db, [String? rev]) {
          return db.get(
            id: 'a',
            fromJsonT: (json) => json,
            rev: rev,
            revs: true,
            conflicts: true,
            meta: true,
          );
        }

        runCompact(Foodb db) async {
          await db.compact();
          await Future.delayed(Duration(seconds: 1));
        }

        var targetDoc;
        var sourceDoc;
        await putDoc(source, ['1-a']);
        await putDoc(source, ['2-a', '1-a']);
        await putDoc(source, ['2-b', '1-a']);
        await runCompact(source);
        await source.revsLimit(1);
        await runCompact(source);
        sourceDoc = await getDoc(source);
        await onetimeReplicate();
        targetDoc = await getDoc(target);

        print(sourceDoc);
      });
    },
    (FoodbTestContext sourceCtx, FoodbTestContext targetCtx) {
      test('repliacte resume on correct checkpoint', () async {
        final source =
            await sourceCtx.db('source-replicate-correct-checkpoint');
        final target =
            await targetCtx.db('target-replicate-correct-checkpoint');

        var complete = expectAsync0(() => {});
        var onSecondResult = expectAsync1((ChangeResult r) {}, count: 1);

        await source.put(doc: Doc(id: 'a', model: {}));
        replicate(source, target, onError: handleTestReplicationError,
            onComplete: () async {
          var docs = await target.allDocs(GetViewRequest(), (json) => json);
          expect(docs.totalRows, equals(1));
          await source.put(doc: Doc(id: 'b', model: {}));
          replicate(source, target, onResult: onSecondResult,
              onComplete: () async {
            var docs = await target.allDocs(GetViewRequest(), (json) => json);
            expect(docs.totalRows, equals(2));
            complete();
          });
        });
      });
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

        replicate(source, target, onComplete: () async {
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
        final source =
            await sourceCtx.db('source-replicate-source-max-batch-size');
        final target =
            await targetCtx.db('target-replicate-target-max-batch-size');

        var complete = expectAsync0(() => {});
        var checkpoint = expectAsync0(() => {}, count: 10);

        await source.bulkDocs(
            body: List.generate(100, (index) => Doc(id: '$index', model: {})));

        replicate(source, target, maxBatchSize: 10, onCheckpoint: (_) async {
          checkpoint();
        }, onComplete: () async {
          var docs = await target.allDocs(GetViewRequest(), (json) => json);
          expect(docs.rows, hasLength(100));
          complete();
        });
      });
      test(
          'repliacte continuous, long debouce, small maxBatchSize, will finish before debounce',
          () async {
        final source =
            await sourceCtx.db('source-continuous-by-max-batch-size');
        final target =
            await targetCtx.db('target-continuous-by-max-batch-size');

        var complete = expectAsync0(() => {});
        var processedCnt = 0;
        var stopwatch = Stopwatch();
        stopwatch.start();

        ReplicationStream? stream;
        stream = replicate(source, target,
            continuous: true,
            maxBatchSize: 10,
            debounce: Duration(seconds: 10), onCheckpoint: (checkpoint) async {
          processedCnt += checkpoint.processed.length;
          if (processedCnt == 30) {
            expect(stopwatch.elapsed.inSeconds, lessThan(10));
            complete();
          }
        });
        Future.delayed(Duration(seconds: 1), () {
          source.bulkDocs(
              body: List.generate(30, (index) => Doc(id: '$index', model: {})));
        });
      });
      test(
          'repliacte continuous, short debouce, large maxBatchSize, will finish after debounce',
          () async {
        final source = await sourceCtx.db('source-continuous-by-debounce');
        final target = await targetCtx.db('target-continuous-by-debounce');

        var complete = expectAsync0(() => {});
        var processedCnt = 0;
        var stopwatch = Stopwatch();
        stopwatch.start();

        ReplicationStream? stream;
        stream = replicate(source, target,
            continuous: true,
            maxBatchSize: 50,
            debounce: Duration(seconds: 5), onCheckpoint: (checkpoint) async {
          processedCnt += checkpoint.processed.length;
          if (processedCnt == 30) {
            expect(stopwatch.elapsed.inSeconds, greaterThan(5));
            complete();
          }
        });
        Future.delayed(Duration(seconds: 1), () {
          source.bulkDocs(
              body: List.generate(30, (index) => Doc(id: '$index', model: {})));
        });
      });
      test(
          'continuous replication, debounce will not fire immediate if no initial change',
          () async {
        final source = await sourceCtx.db('source-tonituous-no-immediate-fire');
        final target = await targetCtx.db('target-tonituous-no-immediate-fire');
        var complete = expectAsync0(() => {});
        var checkpoint = expectAsync0(() => {}, count: 1);
        await source.put(doc: Doc(id: 'a', model: {}));

        ReplicationStream? stream;
        stream = replicate(source, target,
            continuous: true, debounce: Duration(microseconds: 2000),
            onCheckpoint: (event) async {
          checkpoint();
          var doc = await target.get(id: 'a', fromJsonT: (json) => json);
          expect(doc, isNotNull);
          complete();
        });
        Future.delayed(Duration(seconds: 1),
            () => source.put(doc: Doc(id: 'b', model: {})));
      });
      test('continuous replication, fast oepration', () async {
        final source = await sourceCtx.db('source-replicate-fast-operation');
        final target = await targetCtx.db('target-replicate-fast-operation');
        var complete = expectAsync0(() => {});
        var resultCnt = expectAsync1((r) => {}, count: 10);

        replicate(
          source,
          target,
          continuous: true,
          debounce: Duration(milliseconds: 1),
          onResult: resultCnt,
          onError: handleTestReplicationError,
        );
        var list = List.generate(10, (index) => index);
        for (var i in list) {
          await source.put(doc: Doc(id: '$i', model: {}));
        }
        await Future.delayed(Duration(seconds: 3), complete);
      });
    },
    (FoodbTestContext sourceCtx, FoodbTestContext targetCtx) {
      test('replication with client side id filter', () async {
        final source = await sourceCtx.db('source-replicate-id-filter');
        final target = await targetCtx.db('target-replicate-id-filter');
        var complete = expectAsync0(() => {});

        await source.put(doc: Doc(id: 'a_1', model: {}));
        await source.put(doc: Doc(id: 'a_2', model: {}));
        await source.put(doc: Doc(id: 'a_3', model: {}));
        await source.put(doc: Doc(id: 'b_1', model: {}));
        await source.put(doc: Doc(id: 'b_2', model: {}));
        await source.put(doc: Doc(id: 'c_1', model: {}));
        await source.put(doc: Doc(id: 'c_4', model: {}));

        replicate(source, target,
            onError: handleTestReplicationError,
            whereChange: WhereFunction('1', (change) {
              var splitted = change.id.split('_');
              return !['a', 'c'].contains(splitted[0]) ||
                  int.parse(splitted[1]) > 2;
            }), onComplete: () async {
          var docs = await target.allDocs(GetViewRequest(), (json) => json);
          expect(docs.totalRows, 4);
          ['a_3', 'b_1', 'b_2', 'c_4'].forEach((expectedId) {
            expect(docs.rows.where((element) => element.id == expectedId),
                hasLength(1));
          });
          complete();
        });
      });
    }
  ];
}
