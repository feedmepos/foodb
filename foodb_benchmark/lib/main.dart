import 'dart:math';
import 'package:flutter/material.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_benchmark/replicator.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Foodb foodb =
      new Foodb(adapter: KeyValueAdapter(dbName: "a", db: ObjectBox()));
  String startTime = "No Started Yet";
  String endTime = "No Ended Yet";
  String end100Get = "No 100 Get Yet";
  String start100GetAgain = "No Started Yet";
  String end100GetAgain = "No Ended Yet";
  String start1Put = "No Started Yet";
  String end1Put = "No Ended Yet";
  String startDesignDoc = "No Started Yet";
  String endDesignDoc = "No Ended Yet";
  String startDesignDocAgain = "No Started Yet";
  String endDesignDocAgain = "No Ended Yet";

  String generateRandomString(int len) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(children: [
        Container(
            color: Colors.lightBlue,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextButton(
                    onPressed: () async {
                      if (startTime == "No Started Yet") {
                        await foodb.adapter.destroy();
                        Stopwatch stopwatch = new Stopwatch();
                        stopwatch.start();
                        setState(() {
                          startTime =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });

                        await millionPutOperations();
                        setState(() {
                          endTime =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });
                        stopwatch.stop();
                        print("stopwatch ${stopwatch.elapsedMilliseconds}");

                        GetAllDocsResponse<Map<String, dynamic>> allDocs =
                            await foodb.adapter.allDocs<Map<String, dynamic>>(
                                GetAllDocsRequest(
                                    startkey: "l", endkey: "l\uffff"),
                                (json) => json);
                        setState(() {
                          end100Get =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });
                        print("alldocs1 Length: ${allDocs.rows.length}");
                        for (int x = 0; x < allDocs.rows.length; x++) {
                          print(
                              "alldocs1 ${allDocs.rows[x].toJson((value) => value)}");
                        }
                        print("alldocs1 ${allDocs.toJson((value) => value)}");
                        setState(() {
                          start100GetAgain =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });

                        GetAllDocsResponse<Map<String, dynamic>> allDocs2 =
                            await foodb.adapter.allDocs<Map<String, dynamic>>(
                                GetAllDocsRequest(
                                    startkey: "l", endkey: "l\uffff"),
                                (json) => json);
                        setState(() {
                          end100GetAgain =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });
                        print("alldocs2 Length: ${allDocs2.rows.length}");
                        for (int x = 0; x < allDocs2.rows.length; x++) {
                          print(
                              "alldocs2 ${allDocs2.rows[x].toJson((value) => value)}");
                        }
                        print("alldocs2 ${allDocs2.toJson((value) => value)}");
                      }
                    },
                    child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.all(10.0),
                        child: Text("START 1 million Put Operations"))),
                Row(
                  children: [Text("Start Time"), Text(startTime)],
                ),
                Row(
                  children: [Text("End Time"), Text(endTime)],
                ),
                Row(
                  children: [Text("100 Get End Time"), Text(end100Get)],
                ),
                Row(
                  children: [
                    Text("100 Get Start Time Again"),
                    Text(start100GetAgain)
                  ],
                ),
                Row(
                  children: [
                    Text("100 Get End Time Again"),
                    Text(end100GetAgain)
                  ],
                ),
              ],
            )),
        Container(
          color: Colors.lightGreen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(
                  onPressed: () async {
                    if (start1Put == "No Started Yet") {
                      setState(() {
                        start1Put =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                      await foodb.adapter.put(
                          doc: Doc(
                              id: "l${generateRandomString(30)}",
                              model: {"name": "test", "no": 999}));
                      setState(() {
                        end1Put =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                    }
                  },
                  child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "START 1 More Put Operation",
                      ))),
              Row(
                children: [Text("Start 1 Put At"), Text(start1Put)],
              ),
              Row(
                children: [Text("End 1 Put At"), Text(end1Put)],
              ),
            ],
          ),
        ),
        Container(
          color: Colors.limeAccent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(
                  onPressed: () async {
                    if (startDesignDoc == "No Started Yet" || 1 == 1) {
                      await foodb.adapter.createIndex(
                          indexFields: ["name", "no"],
                          ddoc: "name_doc",
                          name: "name_index");
                      setState(() {
                        startDesignDoc =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                      List<AllDocRow<Map<String, dynamic>>> docs =
                          await foodb.adapter.view("name_doc", "name_index",
                              startKey: "_wtf_88",
                              endKey: "_wtf_88\uffff",
                              startKeyDocId: "l",
                              endKeyDocId: "l\uffff");
                      setState(() {
                        endDesignDoc =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                      for (AllDocRow doc in docs) {
                        print("designdocone ${doc.toJson((value) => value)}");
                      }
                      print("designdocone ${docs.length}");

                      setState(() {
                        startDesignDocAgain =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                      List<AllDocRow<Map<String, dynamic>>> docs2 =
                          await foodb.adapter.view("name_doc", "name_index",
                              startKey: "_wtf_88",
                              endKey: "_wtf_88\uffff",
                              startKeyDocId: "l",
                              endKeyDocId: "l\uffff");
                      setState(() {
                        endDesignDocAgain =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });

                      for (AllDocRow doc in docs2) {
                        print("designdocagain ${doc.toJson((value) => value)}");
                      }
                      print("designdocagain ${docs2.length}");
                    }
                  },
                  child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "Start Design AllDoc",
                      ))),
              Row(
                children: [
                  Text("Start Design All Docs "),
                  Text(startDesignDoc)
                ],
              ),
              Row(
                children: [Text("End Design All Docs"), Text(endDesignDoc)],
              ),
              Row(
                children: [
                  Text("Start Design All Docs Again"),
                  Text(startDesignDocAgain)
                ],
              ),
              Row(
                children: [
                  Text("End Design All Docs Again"),
                  Text(endDesignDocAgain)
                ],
              ),
            ],
          ),
        ),
        TextButton(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ReplicatorPage()));
            },
            child: Text('Go Replicator'))
      ]),
    );
  }

  Future<void> millionPutOperations() async {
    List<String> list = [
      'a',
      'b',
      'c',
      'd',
      'e',
      'f',
      'g',
      'h',
      'i',
      'j',
      'k',
      'm',
      'n',
      'o',
      'p',
      'q',
      'r',
      's',
      't',
      'u',
      'v',
      'w',
      'x',
      'y',
      'z'
    ];
    for (String char in list) {
      for (int y = 0; y < 36; y++) {
        String id = "${char}_$y";
        for (int x = 0; x < 10; x++) {
          await foodb.adapter.put(
              doc: Doc(
                  id: id,
                  model: {"name": "wth", "no": 99},
                  rev: Rev.fromString("1-$x")),
              newEdits: false);
        }
      }

      for (int y = 0; y < 4; y++) {
        String id = "${char}__$y";
        for (int x = 0; x < 10; x++) {
          await foodb.adapter.put(
              doc: Doc(
                  id: id,
                  model: {"name": "wtf", "no": 88},
                  rev: Rev.fromString("1-$x")),
              newEdits: false);
        }
      }
    }

    for (int y = 0; y < 8; y++) {
      String id = "l_$y";
      for (int x = 0; x < 10; x++) {
        await foodb.adapter.put(
            doc: Doc(
                id: id,
                model: {"name": "wth", "no": 99},
                rev: Rev.fromString("$y-$x")),
            newEdits: false);
      }
    }

    for (int y = 0; y < 2; y++) {
      String id = "l__$y";
      for (int x = 0; x < 10; x++) {
        await foodb.adapter.put(
            doc: Doc(
                id: id,
                model: {"name": "wtf", "no": 88},
                rev: Rev.fromString("$y-$x")),
            newEdits: false);
      }
    }
  }
}
