import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() async {
  // benchmark(300, 10, InMemoryTestContext());
  // benchmark(3000, 10, InMemoryTestContext());
  replicateBenchmarkTest(300, 10, CouchdbTestContext());
  replicateBenchmarkTest(3000, 10, CouchdbTestContext());
}

void replicateBenchmarkTest(
    int batchSize, int thousand, FoodbTestContext targetCtx) {
  var toType = targetCtx.runtimeType.toString();

  test('Couchdb to $toType: ${thousand}k-benchmark', () async {
    final from = await getCouchDb('a-${thousand}k', persist: true);
    final to = await targetCtx.db('test-benchmark-${thousand}k');

    var totalStopWatch = Stopwatch()..start();
    var cycleStopWatch = Stopwatch()..start();
    var fn = expectAsync1((res) async {
      totalStopWatch.stop();
      print('done: ${totalStopWatch.elapsed.inSeconds}');
      print(
          'perDoc: ${totalStopWatch.elapsed.inMilliseconds / (thousand * 1000)}');
      final fromAll = await from.allDocs(GetViewRequest(), (json) => json);
      final toAll = await from.allDocs(GetViewRequest(), (json) => json);
      expect(fromAll.totalRows, equals(toAll.totalRows));
    });

    final stream = await replicate(
      from,
      to,
      maxBatchSize: batchSize,
      createTarget: true,
    );
    stream.listen(
        onError: (err) {
          throw err.err;
        },
        onComplete: fn,
        onCheckpoint: (evnt) {
          print(evnt.log.model.sourceLastSeq);
          print(evnt.processed.length);
          final elapsed = cycleStopWatch.elapsed;
          cycleStopWatch.reset();
          print('done cycle: ${elapsed.inSeconds}');
          print('perchange: ${elapsed.inMilliseconds / evnt.processed.length}');
        });
  }, timeout: Timeout(Duration(minutes: 30)));
}