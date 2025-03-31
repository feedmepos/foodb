// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:foodb_server/abstract_foodb_server.dart';
import 'package:foodb_server/types.dart';

import 'package:foodb_flutter_test/main.dart';

class IsolateServerEnv {
  String dbName;
  ByteData objectboxStoreReference;
  SendPort mainIsolateSendPort;
  KeyvalueFoodbIsolateRef keyvalueIsolateReference;
  IsolateServerEnv({
    required this.dbName,
    required this.objectboxStoreReference,
    required this.mainIsolateSendPort,
    required this.keyvalueIsolateReference,
  });
}

startIsolateFoodbServer(IsolateServerEnv env) async {
  env.mainIsolateSendPort.send('Creating Store');
  Store store = Store.fromReference(
    getObjectBoxModel(),
    env.objectboxStoreReference,
  );
  env.mainIsolateSendPort.send('Created Store');

  env.mainIsolateSendPort.send('Launching Server');
  final server = FoodbServer.http(
      dbFactory: (dbName) async {
        final db = Foodb.keyvalue(
          dbName: env.dbName,
          keyValueDb: ObjectBoxAdapter(store),
        );
        db as KeyvalueFoodb;
        await db.initDb();
        db.addIsolateMembership(env.keyvalueIsolateReference);
        return db;
      },
      config: FoodbServerConfig(auths: [
        DatabaseAuth(
          database: env.dbName,
          username: 'admin',
          password: '123',
        ),
      ]));
  await server.start(port: 5984);
  env.mainIsolateSendPort.send('Launched Server');

  ReceivePort receivePort = ReceivePort();
  env.mainIsolateSendPort.send(receivePort.sendPort);
}

class TestIsolateServerPage extends StatefulWidget {
  const TestIsolateServerPage({Key? key}) : super(key: key);

  static String title = 'Test Isolate Server Page';

  @override
  State<TestIsolateServerPage> createState() => _TestIsolateServerPageState();
}

class _TestIsolateServerPageState extends State<TestIsolateServerPage> {
  KeyvalueFoodb? mainIsolateFoodb;
  List<String> mainLogs = [];
  Isolate? foodbServerIsolate;
  List<String> foodbServerLogs = [];
  final foodbServerIsolateReceivePort = ReceivePort();
  SendPort? foodbServerIsolateSendPort;
  Foodb? isolateFoodbClient;
  List<String> clientLogs = [];
  final dbName = 'main-isolate-foodb';

  @override
  void initState() {
    super.initState();
  }

  initMainFoodb() async {
    mainIsolateFoodb = Foodb.keyvalue(
        dbName: dbName,
        keyValueDb: ObjectBoxAdapter(GlobalStore.store)) as KeyvalueFoodb;
    await mainIsolateFoodb!.initDb();
    setState(() {
      mainLogs.insert(0, 'main server started');
    });
    mainIsolateFoodb!.changesStream(
        ChangeRequest(
          feed: ChangeFeed.continuous,
          since: 'now',
        ), onResult: (r) {
      setState(() {
        mainLogs.insert(0, 'received change result ${r.id}');
      });
    });
    setState(() {
      mainLogs.insert(0, 'listening to change stream');
    });
  }

  initIsolateFoodbServer() async {
    foodbServerIsolateReceivePort.listen((msg) {
      if (msg is SendPort) {
        foodbServerIsolateSendPort = msg;
      }
      if (msg is String) {
        setState(() {
          foodbServerLogs.insert(0, msg);
        });
      }
    });
    foodbServerIsolate = await Isolate.spawn(
        startIsolateFoodbServer,
        IsolateServerEnv(
            dbName: dbName,
            objectboxStoreReference: GlobalStore.store.reference,
            mainIsolateSendPort: foodbServerIsolateReceivePort.sendPort,
            keyvalueIsolateReference: mainIsolateFoodb!.isolateReference));
    await mainIsolateFoodb!.initDb();
  }

  initFoodbServerClient() async {
    isolateFoodbClient = Foodb.couchdb(
        dbName: dbName, baseUri: Uri.parse('http://admin:123@127.0.0.1:5984'));
    await isolateFoodbClient!.initDb();

    setState(() {
      clientLogs.insert(0, 'client connected');
    });
    mainIsolateFoodb!.changesStream(
        ChangeRequest(
          feed: ChangeFeed.continuous,
          since: 'now',
        ), onResult: (r) {
      setState(() {
        clientLogs.insert(0, 'received change result ${r.id}');
      });
    });
    setState(() {
      clientLogs.insert(0, 'listening to change stream');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TestIsolateServerPage.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Row(
              children: [
                if (mainIsolateFoodb == null)
                  ElevatedButton(
                      onPressed: () async {
                        initMainFoodb();
                      },
                      child: Text('init Foodb')),
                if (mainIsolateFoodb != null)
                  ElevatedButton(
                      onPressed: () async {
                        mainIsolateFoodb!.put(
                            doc: Doc(
                                id: DateTime.now().toIso8601String(),
                                model: {}));
                      },
                      child: Text('Add doc to main Foodb')),
                if (mainIsolateFoodb != null && foodbServerIsolate == null)
                  ElevatedButton(
                      onPressed: () async {
                        initIsolateFoodbServer();
                      },
                      child: Text('init isolate server')),
                if (foodbServerIsolate != null && isolateFoodbClient == null)
                  ElevatedButton(
                      onPressed: () async {
                        initFoodbServerClient();
                      },
                      child: Text('init foodb server client')),
                if (isolateFoodbClient != null)
                  ElevatedButton(
                      onPressed: () async {
                        isolateFoodbClient!.put(
                            doc: Doc(
                                id: DateTime.now().toIso8601String(),
                                model: {}));
                      },
                      child: Text('Add doc to main Foodb')),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: [
                Column(
                  children: [
                    Text('main foodb logs'),
                    SingleChildScrollView(
                      child: Column(
                        children: mainLogs.map((l) => Text(l)).toList(),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('foodb server logs'),
                    SingleChildScrollView(
                      child: Column(
                        children: foodbServerLogs.map((l) => Text(l)).toList(),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('client logs'),
                    SingleChildScrollView(
                      child: Column(
                        children: clientLogs.map((l) => Text(l)).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
