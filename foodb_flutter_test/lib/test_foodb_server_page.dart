import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
      print('STOPPED');
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

  List<Doc<Map<String, dynamic>>> docs = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMainServer() async {
    server = await _initMainServer(_getObjectboxDb);
    await _connectMainServer();
    _listenChanges();
  }

  _listenChanges() {
    foodb?.changesStream(
      ChangeRequest(
        feed: 'continuous',
        includeDocs: true,
        since: 'now',
        heartbeat: 30000,
      ),
      onResult: (result) {
        print('changes ${result.id}');
        if (result.doc != null) {
          docs.add(result.doc!);
        }
      },
      onError: (e, s) async {
        // localDbChangeStream.sink
        //     .add(ChangeResultOrException(exception: e, stacktrace: s));
        // stream.cancel();
        // onError?.call();
      },
    );
  }

  Future<void> _startIsolateMainServer() async {
    final receivePort = ReceivePort();
    final completer = Completer();
    receivePort.listen((message) {
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
    isolate = await Isolate.spawn(_startMainServerInIsolate, {
      'getObjectboxDb': _getObjectboxDb,
      'sendPort': receivePort.sendPort,
      'token': token,
    });
    await completer.future;
    await _connectMainServer();
    _listenChanges();
  }

  Future<void> _connectMainServer() async {
    setState(() {
      foodb = Foodb.couchdb(
          dbName: DB_NAME,
          baseUri:
              Uri.parse('http://$DB_USERNAME:$DB_PASSWORD@127.0.0.1:6984'));
    });
    await foodb!.info();
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
                ...[10, 100, 1000, 3000, 5000, 10000].map((count) => ElevatedButton(
                      child: Text('test $count'),
                      onPressed: () async {
                        await FoodbDebug.timed('test $count', () async {
                          final futures = List.generate(count, (index) async {
                            final now = DateTime.now().toIso8601String();
                            final doc = await foodb?.put(
                                doc: Doc(id: '${now}_$index', model: {}));
                            print(doc?.id);
                          });
                          final allDocs = await foodb?.allDocs(
                              GetViewRequest(startkey: '', endkey: '\ufff0'),
                              (json) => null);
                          print(allDocs?.totalRows);
                          await Future.wait(futures);
                        });
                      },
                    ))
              ],
            ),
          ],
        ),
      ),
    );
  }
}
