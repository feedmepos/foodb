import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_flutter_test/main.dart';
import 'package:foodb_flutter_test/telemetry.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:path_provider/path_provider.dart';

class TestFoodbServerPage extends StatefulWidget {
  const TestFoodbServerPage({Key? key}) : super(key: key);

  static String title = 'Test Foodb Server Page';

  @override
  State<TestFoodbServerPage> createState() => _TestFoodbServerPageState();
}

const DB_NAME = "test-db";
const DB_USERNAME = "test-db";
const DB_PASSWORD = "test-db";
var random = Random();

String generateRandomString(int length, Random random) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(length, (index) => chars[random.nextInt(chars.length)])
      .join();
}

class RunResult {
  Map<String, DateTime> checkpoint = {};
  check(String point) {
    checkpoint[point] = DateTime.now();
  }

  @override
  String toString() {
    var checkpointStr =
        checkpoint.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    var timespentStr =
        timespent.entries.map((e) => '${e.key}: ${e.value} seconds').join(', ');
    return 'Checkpoints: { $checkpointStr }\nTime Spent: { $timespentStr }';
  }

  Map<String, num> get timespent {
    Map<String, num> timeDifferences = {};
    DateTime? previousTime;
    String? previousPoint;

    for (var entry in checkpoint.entries) {
      if (previousTime != null && previousPoint != null) {
        // Calculate the difference in seconds and store it in the map
        num differentInMilliseconds =
            entry.value.difference(previousTime).inMilliseconds;
        timeDifferences['$previousPoint -> ${entry.key}'] =
            differentInMilliseconds;
      }
      // Update previousTime and previousPoint for the next iteration
      previousTime = entry.value;
      previousPoint = entry.key;
    }
    return timeDifferences;
  }
}

// Function to calculate average and p99 for each checkpoint transition across multiple RunResult objects
Map<String, Map<String, num>> calculateStats(List<RunResult> results) {
  // Initialize a map to store times for each checkpoint transition
  Map<String, List<num>> timesByTransition = {};

  // Collect all time spent values from each RunResult and organize them by transition
  for (var result in results) {
    result.timespent.forEach((transition, time) {
      timesByTransition.putIfAbsent(transition, () => []).add(time);
    });
  }

  // Calculate average and p99 for each transition
  Map<String, Map<String, num>> statsByTransition = {};

  timesByTransition.forEach((transition, times) {
    if (times.isNotEmpty) {
      // Calculate average
      num average = times.reduce((a, b) => a + b) / times.length;

      // Calculate p99
      times.sort();
      int p99Index = (times.length * 0.99).floor();
      num p99 = times[min(p99Index, times.length - 1)];

      // Store the stats for this transition
      statsByTransition[transition] = {
        "average": average,
        "p99": p99,
      };
    } else {
      // If no times recorded, set stats to zero
      statsByTransition[transition] = {
        "average": 0,
        "p99": 0,
      };
    }
  });

  return statsByTransition;
}

Future<FoodbServer> _initMainServer(dynamic getObjectboxDb) async {
  GlobalStore.store = await openStore();
  FoodbServer server;
  final Directory dir = await getApplicationSupportDirectory();
  final config = FoodbServerConfig(
    auths: [
      DatabaseAuth(
        database: DB_NAME,
        username: DB_USERNAME,
        password: DB_PASSWORD,
      )
    ],
  );
  server = FoodbServer.http(
    dbFactory: (dbName) => getObjectboxDb(dbName, dir.path),
    config: config,
  );
  await server.start();
  return server;
}

Future<void> _startMainServerInIsolate(Map<String, dynamic> input) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(input['token']);
  FoodbDebug.logLevel = LOG_LEVEL.trace;
  final receivePort = ReceivePort();
  final sendPort = input['sendPort'] as SendPort;
  var server = await _initMainServer(input['getObjectboxDb']);
  receivePort.listen((message) async {
    print('isolate:: $message');
    if (message == "STOP") {
      print('STOPPING');
      await server.stop();
      final storeDir = Directory(
          (await getApplicationDocumentsDirectory()).path + '/objectbox');
      final telemetry2 = Telemetry.start("_startMainServerInIsolate.listSync");
      final files = storeDir.listSync();
      for (var file in files) {
        file.deleteSync();
      }
      telemetry2.end("_startMainServerInIsolate.listSync.done");
      GlobalStore.store.close();
      sendPort.send("STOPPPPPPPPED");
    }
  });
  sendPort.send("TEST");
  sendPort.send(receivePort.sendPort);
}

Future<Foodb> _getObjectboxDb(String dbName, String path) async {
  final db = ObjectBoxAdapter(GlobalStore.store);
  return Foodb.keyvalue(dbName: dbName, keyValueDb: db, autoCompaction: true);
}

class _TestFoodbServerPageState extends State<TestFoodbServerPage> {
  Foodb? foodb;
  FoodbServer? server;
  Isolate? isolate;
  SendPort? sendPort;
  Completer? serverStopCompleter;

  Map<num, RunResult> results = {};

  Map<String, Map<String, num>> resultStats = {};

  List<Doc<Map<String, dynamic>>> docs = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMainServer() async {
    final telemetry = Telemetry.start("_startMainServer._initMainServer");
    server = await _initMainServer(_getObjectboxDb);
    telemetry.end();
    final telemetry2 = Telemetry.start("_startMainServer._connectMainServer");
    await _connectMainServer();
  }

  Future<void> _startIsolateMainServer() async {
    final receivePort = ReceivePort();
    final completer = Completer();
    receivePort.listen((message) async {
      print('main:: $message');
      if (message is SendPort) {
        sendPort = message;
        return;
      }
      if (message == "TEST") {
        completer.complete();
        return;
      }
      if (message == "STOPPPPPPPPED") {
        serverStopCompleter?.complete();

        return;
      }
    });
    final token = RootIsolateToken.instance;
    final telemetry =
        Telemetry.start("_startIsolateMainServer._startMainServerInIsolate");
    isolate = await Isolate.spawn(_startMainServerInIsolate, {
      'getObjectboxDb': _getObjectboxDb,
      'sendPort': receivePort.sendPort,
      'token': token,
    });
    await completer.future;
    telemetry.end();
    final telemetry2 =
        Telemetry.start("_startIsolateMainServer._connectMainServer");
    await _connectMainServer();
  }

  Future<void> _connectMainServer() async {
    setState(() {
      foodb = Foodb.couchdb(
          dbName: DB_NAME,
          baseUri:
              Uri.parse('http://$DB_USERNAME:$DB_PASSWORD@127.0.0.1:6984'));
    });
    await foodb!.info();
    foodb?.changesStream(
      ChangeRequest(
        feed: 'continuous',
        includeDocs: true,
        since: 'now',
        heartbeat: 30000,
      ),
      onResult: (result) {
        print('changes ${result.id}');
        final index = num.parse(result.id.split('_')[0]);
        results[index]?.check('receiveChange');
      },
      onError: (e, s) async {
        // localDbChangeStream.sink
        //     .add(ChangeResultOrException(exception: e, stacktrace: s));
        // stream.cancel();
        // onError?.call();
      },
    );
  }

  Future<void> _stopIsolate() async {
    sendPort?.send("STOP");
    serverStopCompleter = Completer();
    await serverStopCompleter!.future;
    if (isolate != null) {
      isolate!.kill();
      isolate = null;
    }
    foodb = null;
    setState(() {});
  }

  Future<void> _resetMainServer() async {
    await foodb?.destroy();
    foodb = null;
    final telemetry = Telemetry.start("_resetMainServer.stop");
    await server?.stop();
    telemetry.end('_resetMainServer.stop.done');
    final storeDir = Directory(
        (await getApplicationDocumentsDirectory()).path + '/objectbox');
    final telemetry2 = Telemetry.start("_resetMainServer.listSync");
    final files = storeDir.listSync();
    for (var file in files) {
      file.deleteSync();
    }
    telemetry2.end("_resetMainServer.listSync.done");
    GlobalStore.store.close();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TestFoodbServerPage.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (foodb == null)
              ElevatedButton(
                onPressed: _startMainServer,
                child: Text('start main server'),
              ),
            if (foodb == null && isolate == null)
              ElevatedButton(
                onPressed: _startIsolateMainServer,
                child: Text('start isolate main server'),
              ),
            if (foodb != null)
              Wrap(
                direction: Axis.vertical,
                children: [
                  Text('Connected'),
                  if (isolate != null)
                    ElevatedButton(
                      onPressed: _stopIsolate,
                      child: Text('stop isolate'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _resetMainServer,
                      child: Text('reset main server'),
                    ),
                ],
              ),
            Wrap(
              children: [
                ...[
                  10,
                  100,
                  1000,
                  3000,
                  5000,
                  10000
                ].map((count) => ElevatedButton(
                      child: Text('test $count'),
                      onPressed: () async {
                        for (var index = 0; index < count; ++index) {
                          final now = DateTime.now().toIso8601String();
                          final run = RunResult();
                          setState(() {
                            results[index] = run;
                          });
                          run.check('startPut');
                          final doc = await foodb?.put(
                              doc: Doc(id: '${index}_$now', model: {
                            'data': [1000]
                                .map((e) => {
                                      'id': random.nextInt(1000000),
                                      'name': 'Item ${random.nextInt(1000)}',
                                      'description':
                                          generateRandomString(100, random),
                                      'price': (random.nextDouble() * 100)
                                          .toStringAsFixed(2),
                                      'tags': List.generate(
                                          5,
                                          (_) =>
                                              generateRandomString(10, random)),
                                      'created_at': DateTime.now()
                                          .subtract(Duration(
                                              days: random.nextInt(365)))
                                          .toIso8601String(),
                                    })
                                .toList()
                          }));
                          run.check('donePut');
                          run.check('startAllDoc');
                          final allDocs = await foodb?.allDocs(
                              GetViewRequest(startkey: '', endkey: '\ufff0'),
                              (json) => null);
                          run.check('doneAllDoc');
                        }
                        setState(() {
                          resultStats = calculateStats(results.values.toList());
                        });
                      },
                    ))
              ],
            ),
            Text('run completed: ${results.keys.length}'),
            Text(resultStats.toString())
          ],
        ),
      ),
    );
  }
}
