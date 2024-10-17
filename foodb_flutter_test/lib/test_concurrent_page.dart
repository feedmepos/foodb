import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  int frameId = 0;
  int totalTime = 0;
  int totalFrames = 0;
  int maxLag = 0;
  DateTime dt = DateTime.now();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((Duration runtime) {
        frameId += 1;
        if (DateTime.now().difference(dt).inMilliseconds > maxLag) {
          maxLag = DateTime.now().difference(dt).inMilliseconds;
        }
        dt = DateTime.now();
    });

  }

  foodbForTest(String name, Future Function(Foodb) func) async {
    var db = Foodb.keyvalue(
        dbName: name, keyValueDb: ObjectBoxAdapter(GlobalStore.store)
    );
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
            CircularProgressIndicator(),
            Column(
              children: [
                ...[10, 100, 1000, 3000, 5000, 10000].map((count) => ElevatedButton(
                  child: Text('test $count'),
                  onPressed: () async {
                    setState(() {

                      maxLag = 0;
                    });
                    var startFrames = frameId;
                    var t = DateTime.now();
                    await FoodbDebug.timed('test $count', () async {
                      await foodbForTest('test $count', (db) async {
                        await Future.wait(
                            List.generate(
                                count,
                                    (index) => db.put(doc: Doc(id: index.toString(), model: {})
                                )
                            )
                        );
                        var docs = await db.allDocs(GetViewRequest(), (json) => json);
                        setState(() {
                          totalDoc = docs.totalRows;
                        });
                      });
                    });
                    var endFrames = frameId;
                    setState(() {
                      totalFrames = endFrames - startFrames;
                      totalTime = DateTime.now().difference(t).inMilliseconds;
                    });
                  },
                ))
              ],
            ),
            Text('total docs: $totalDoc'),
            Text('total time: $totalTime ms'),
            Text('max lag: $maxLag ms'),
            Text('total frames: $totalFrames'),
            Text('average fps: ${totalFrames / totalTime * 1000}'),
          ],
        ),
      ),
    );
  }
}
