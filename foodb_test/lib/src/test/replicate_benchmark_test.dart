import 'dart:math';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() async {
  // benchmark(300, 10, InMemoryTestContext());
  // benchmark(3000, 10, InMemoryTestContext());
  FoodbDebug.logLevel = LOG_LEVEL.debug;
  replicateBenchmarkTest(
    source: CouchdbTestContext(),
    // source: InMemoryTestContext(),
    // target: CouchdbTestContext(),
    target: InMemoryTestContext(),
    batchSize: 300,
    thousandDoc: 10,
  );
  // replicateBenchmarkTest(3000, 10, CouchdbTestContext());
}

Future<void> generateSourceDb(
    {required Foodb db, required int docCount}) async {
  var batch = 100;
  var docs = <Doc<Map<String, dynamic>>>[];
  const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  var _rnd = Random();
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  for (var i = 0; i < docCount; ++i) {
    var doc = Doc(
      id: '$i',
      model: Map<String, dynamic>.from(List.generate(
        30,
        (index) => 'field$index',
      ).asMap().map(
            (key, value) => MapEntry(
              value,
              getRandomString(300),
            ),
          )),
    );
    docs.add(doc);
    if (i % batch == 0) {
      await db.bulkDocs(body: docs);
      docs = [];
    }
  }
  if (docs.isNotEmpty) {
    await db.bulkDocs(body: docs);
  }
}

void replicateBenchmarkTest({
  required FoodbTestContext source,
  required FoodbTestContext target,
  required int batchSize,
  required int thousandDoc,
  String? customSourceDb,
  bool resetSource = false,
}) {
  var fromType = source.runtimeType.toString();
  var toType = target.runtimeType.toString();
  test('$fromType to $toType: ${thousandDoc}k-benchmark', () async {
    var from;
    if (customSourceDb != null) {
      from = await source.db(customSourceDb, persist: true, prefix: '');
    } else {
      from = await source.db('replication-benchmark-source-${thousandDoc}k',
          persist: true);
    }
    final to = await target.db('replication-benchmark-target-${thousandDoc}k');

    var fromInfo = await from.info();
    if (fromInfo.docCount == 0 || resetSource) {
      await from.destroy();
      await from.initDb();
      await generateSourceDb(
        db: from,
        docCount: thousandDoc * 1000,
      );
    }

    var totalStopWatch = Stopwatch()..start();
    var fn = expectAsync0(() async {
      totalStopWatch.stop();
      print('done: ${totalStopWatch.elapsed.inSeconds}');
      print(
          'perDoc: ${totalStopWatch.elapsed.inMilliseconds / (thousandDoc * 1000)}');
      final fromAll = await from.allDocs(GetViewRequest(), (json) => json);
      final toAll = await from.allDocs(GetViewRequest(), (json) => json);
      expect(fromAll.totalRows, equals(toAll.totalRows));
    });

    replicate(
      from,
      to,
      maxBatchSize: batchSize,
      createTarget: true,
      onError: (e, s) {
        throw e ?? Exception();
      },
      onComplete: fn,
    );
  }, timeout: Timeout(Duration(minutes: 30)));
}
