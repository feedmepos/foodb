import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_flutter_test/main.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
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
                ...[10, 100, 1000, 3000, 5000].map((count) => ElevatedButton(
                      child: Text('test $count'),
                      onPressed: () async {
                        await FoodbDebug.timed('test $count', () async {
                          await foodbForTest('test $count', (db) async {
                            await Future.wait(List.generate(count, (index) {
                              return [
                                db.put(
                                    doc: Doc(id: index.toString(), model: {})),
                              ];
                            }).expand((e) => e));
                            var docs = await db.allDocs(
                                GetViewRequest(), (json) => json);
                            setState(() {
                              totalDoc = docs.totalRows;
                            });
                          });
                        });
                      },
                    )),
                ElevatedButton(
                    child: Text('No winner'),
                    onPressed: () async {
                      await FoodbDebug.timed('test winner', () async {
                        await foodbForTest('test winner', (db) async {
                          await db.createIndex(
                              index: QueryViewOptionsDef(fields: ['a']));
                          var doc1 =
                              await db.put(doc: Doc(id: '1', model: {'a': 1}));
                          var doc2 =
                              await db.put(doc: Doc(id: '2', model: {'a': 1}));
                          var findResult = await db.find(
                              FindRequest(
                                  selector:
                                      EqualOperator(key: 'a', expected: 1)),
                              (p0) => p0);
                          // doc1 = await db.put(
                          //     doc:
                          //         Doc(id: '1', model: {'a': 1}, rev: doc1.rev));
                          print(findResult.toJson((value) => value));
                          db.put(
                              doc: Doc(
                                  id: '1',
                                  model: {'a': 1},
                                  rev: doc1.rev,
                                  deleted: true));
                          db.put(
                              doc:
                                  Doc(id: '2', model: {'a': 1}, rev: doc2.rev));
                          var changeReq = Completer<ChangeResponse>();
                          await Future.delayed(Duration(seconds: 1));
                          db.changesStream(ChangeRequest(since: '0'),
                              onComplete: changeReq.complete);
                          print((await changeReq.future).toJson());
                          findResult = await db.find(
                              FindRequest(
                                  selector:
                                      EqualOperator(key: 'a', expected: 1)),
                              (p0) => p0);
                          print(findResult.toJson((value) => value));
                          setState(() {
                            totalDoc = 1;
                          });
                        });
                      });
                    }),
                ElevatedButton(
                    child: Text('recreate deleted doc'),
                    onPressed: () async {
                      await FoodbDebug.timed('recreate deleted doc', () async {
                        await foodbForTest('recreate deleted doc', (db) async {
                          var a = await db.put(doc: Doc(id: '1', model: {}));
                          await db.delete(id: '1', rev: a.rev);
                          await db.put(doc: Doc(id: '1', model: {}));
                          var changeReq = Completer<ChangeResponse>();
                          db.changesStream(ChangeRequest(since: '0'),
                              onComplete: changeReq.complete);
                          var changeResult = await changeReq.future;
                          print(changeResult.toJson());
                        });
                      });
                    })
              ],
            ),
            Text('total docs: $totalDoc')
          ],
        ),
      ),
    );
  }
}
