import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodb_flutter_test/main.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb/foodb.dart';
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
  var server = _initMainServer(input['getObjectboxDb']);
  input['sendPort'].send(server);
}

Future<Foodb> _getObjectboxDb(String dbName, String path) async {
  final db = ObjectBoxAdapter(GlobalStore.store);
  return Foodb.keyvalue(dbName: dbName, keyValueDb: db, autoCompaction: true);
}

class _TestFoodbServerPageState extends State<TestFoodbServerPage> {
  Foodb? foodb;
  FoodbServer? server;

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
    final token = RootIsolateToken.instance;
    Isolate.spawn(_startMainServerInIsolate, {
      'getObjectboxDb': _getObjectboxDb,
      'sendPort': receivePort.sendPort,
      'token': token,
    });
    server = await receivePort.first;
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

  Future<void> _resetMainServer() async {
    foodb = null;
    server?.stop();
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
              Wrap(
                children: [
                  ElevatedButton(
                    onPressed: _startMainServer,
                    child: Text('start main server'),
                  ),
                  ElevatedButton(
                    onPressed: _startIsolateMainServer,
                    child: Text('start isolate main server'),
                  ),
                ],
              ),
            if (foodb != null)
              Wrap(
                children: [
                  Text('Connected'),
                  ElevatedButton(
                    onPressed: _startIsolateMainServer,
                    child: Text('reset server'),
                  ),
                ],
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
