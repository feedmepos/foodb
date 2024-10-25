import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_flutter_test/main.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMainServer() async {
    server = await _initMainServer(_getObjectboxDb);
    await _connectMainServer();
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
      setState(() {});
    }
  }

  Future<void> _resetMainServer() async {
    await foodb?.destroy();
    foodb = null;
    await server?.stop();
    final storeDir = Directory((await getApplicationDocumentsDirectory()).path + '/objectbox');
    final files = storeDir.listSync();
    for (var file in files) {
      file.deleteSync();
    }
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
            if (isolate == null)
              ElevatedButton(
                onPressed: _startIsolateMainServer,
                child: Text('start isolate main server'),
              ),
            if (foodb != null)
              Wrap(
                children: [
                  Text('Connected'),
                  ElevatedButton(
                    onPressed: _resetMainServer,
                    child: Text('reset main server'),
                  ),
                ],
              ),
            if (isolate != null)
              ElevatedButton(
                onPressed: _stopIsolate,
                child: Text('stop isolate'),
              ),
            Wrap(
              children: [
                ...[10, 100, 1000, 3000, 5000].map((count) => ElevatedButton(
                      child: Text('test $count'),
                      onPressed: () async {
                        await FoodbDebug.timed('test $count', () async {});
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
