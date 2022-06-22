import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_flutter_test/main.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

import 'package:foodb/foodb.dart';

class TestObjectboxPage extends StatefulWidget {
  const TestObjectboxPage({Key? key}) : super(key: key);

  static String title = 'Test Objectbox Page';

  @override
  State<TestObjectboxPage> createState() => _TestObjectboxPageState();
}

class _TestObjectboxPageState extends State<TestObjectboxPage> {
  Foodb? db;
  Store? store;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TestObjectboxPage.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                ElevatedButton(
                    child: Text('load db'),
                    onPressed: () async {
                      store = await openStore(directory: './test/db');
                      db = Foodb.keyvalue(
                          dbName: 'test', keyValueDb: ObjectBoxAdapter(store!));
                      setState(() {});
                    }),
                ElevatedButton(
                    child: Text('load key'),
                    onPressed: () async {
                      var data = await db!.keyValueAdapter!.read(DocKey(),
                          desc: false,
                          inclusiveStart: true,
                          inclusiveEnd: true);
                      var ids =
                          data.records.values.map((e) => e['id']).toList();
                      print(data);
                    }),
              ],
            ),
            Text('store: $store, db: $db')
          ],
        ),
      ),
    );
  }
}
