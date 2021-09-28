import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/methods/view.dart';
import 'package:foodb/replicate.dart';

import 'adapter/adapter_test.dart';

void main() async {
  test('Couchdb to Couchdb: 30k-benchmark', () async {
    final from = await getCouchDbAdapter("a-1k", persist: true);
    final to = await getCouchDbAdapter('test-benchmark', persist: true);

    Stopwatch stopwatch = new Stopwatch()..start();
    var fn = expectAsync1((res) async {
      stopwatch.stop();
      print('done: ${stopwatch.elapsed.inSeconds}');
      print('perDoc: ${stopwatch.elapsed.inMilliseconds / 1000}');
      final fromAll = await from.allDocs(GetViewRequest(), (json) => json);
      final toAll = await from.allDocs(GetViewRequest(), (json) => json);
      expect(fromAll.totalRows, equals(toAll.totalRows));
    });

    final stream = await replicate(
        from,
        to,
        ReplicationConfig(
          maxBatchSize: 300,
          createTarget: true,
        ));
    stream.listen(
        onError: (err) {
          print(err);
        },
        onComplete: fn,
        onCheckpoint: (evnt) {
          print(evnt.log);
          print(evnt.processed);
        });
  }, timeout: Timeout(Duration(minutes: 30)));
}
