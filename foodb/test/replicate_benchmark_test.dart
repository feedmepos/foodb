import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/methods/view.dart';
import 'package:foodb/replicate.dart';

import 'adapter/adapter_test.dart';

void main() async {
  // benchmark(300, 10, InMemoryAdapterTestContext());
  // benchmark(3000, 10, InMemoryAdapterTestContext());
  benchmark(300, 10, CouchdbAdapterTestContext());
  benchmark(3000, 10, CouchdbAdapterTestContext());
}

benchmark(int batchSize, int thousand, AdapterTestContext targetCtx) {
  String toType = targetCtx.runtimeType.toString();

  test('Couchdb to $toType: ${thousand}k-benchmark', () async {
    final from = await getCouchDbAdapter("a-${thousand}k", persist: true);
    final to = await targetCtx.db('test-benchmark');

    Stopwatch stopwatch = new Stopwatch()..start();
    var fn = expectAsync1((res) async {
      stopwatch.stop();
      print('done: ${stopwatch.elapsed.inSeconds}');
      print('perDoc: ${stopwatch.elapsed.inMilliseconds / (thousand * 1000)}');
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
          print(err);
          throw err;
        },
        onComplete: fn,
        onCheckpoint: (evnt) {
          print(evnt.log.model.sourceLastSeq);
          print(evnt.processed.length);
        });
  }, timeout: Timeout(Duration(minutes: 30)));
}
