import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_flutter_test/telemetry.dart';
import 'package:foodb_flutter_test/test_concurrent_page.dart';
import 'package:foodb_flutter_test/test_foodb_server_page.dart';
import 'package:foodb_flutter_test/test_http_client_page.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

class GlobalStore {
  static late Store store;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FoodbDebug.logLevel = LOG_LEVEL.debug;
  HttpOverrides.global = MyHttpOverrides();

  final telemetry = Telemetry.start("openStore");
  GlobalStore.store = await openStore();
  telemetry.end('openStore done');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main page'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              child: Text(TestFoodbServerPage.title),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TestFoodbServerPage()),
                );
              },
            ),
            ElevatedButton(
              child: Text(TestHttpClientPage.title),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TestHttpClientPage()),
                );
              },
            ),
            ElevatedButton(
              child: Text(TestConcurrentPage.title),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TestConcurrentPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
