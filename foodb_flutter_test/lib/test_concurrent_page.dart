import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodb_flutter_test/main.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

import 'package:foodb/foodb.dart';

class TestConcurrentPage extends StatefulWidget {
  const TestConcurrentPage({Key? key}) : super(key: key);

  static String title = 'Test Concurrent Page';

  @override
  State<TestConcurrentPage> createState() => _TestConcurrentPageState();
}

class _TestConcurrentPageState extends State<TestConcurrentPage> {
  int testCount = 1;
  int totalDoc = 0;

  @override
  void initState() {
    super.initState();
  }

  foodbForTest(String name, Future Function(Foodb) func) async {
    var db = Foodb.keyvalue(
        dbName: name, keyValueDb: ObjectBoxAdapter(GlobalStore.store));
    try {
      await func(db);
    } catch (err) {
      print(err);
    } finally {
      await db.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TestConcurrentPage.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                ...[10, 100, 1000, 3000, 5000, 10000].map((count) => ElevatedButton(
                      child: Text('test $count'),
                      onPressed: () async {
                        GlobalStore.store = await openStore();
                        await FoodbDebug.timed('test $count', () async {
                          await foodbForTest('test $count', (db) async {
                            await Future.wait(List.generate(
                                count,
                                (index) => db.put(
                                    doc:
                                        Doc(id: index.toString(), model: {}))));
                            var docs = await db.allDocs(
                                GetViewRequest(), (json) => json);
                            setState(() {
                              totalDoc = docs.totalRows;
                            });
                          });
                        });

                        GlobalStore.store.close();
                      },
                    ))
              ],
            ),
            Text('total docs: $totalDoc')
          ],
        ),
      ),
    );
  }
}
