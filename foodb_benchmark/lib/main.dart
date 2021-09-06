import 'dart:math';
import 'package:flutter/material.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart' as all_docs;
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_sqflite_adapter/sqlite_database/foodb_sqflite_database.dart';
import 'package:foodb_sqflite_adapter/sqlite_database/sqlite_provider.dart';

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
  Foodb foodb = new Foodb(
      adapter: KeyValueAdapter(dbName: "a", db: SqliteDatabase(dbName: "a")));
  String startTime = "No Started Yet";
  String endTime = "No Ended Yet";
  String end100Get = "No 100 Get Yet";
  String start1Put = "No Started Yet";
  String end1Put = "No Ended Yet";
  String startDesignDoc = "No Started Yet";
  String endDesignDoc = "No Ended Yet";

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
                        await SqliteProvider(dbName: "a").removeDatabase();
                        setState(() {
                          startTime =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });

                        await millionPutOperations();
                        setState(() {
                          endTime =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });

                        all_docs.GetAllDocs<Map<String, dynamic>> allDocs =
                            await foodb.adapter.allDocs<Map<String, dynamic>>(
                                all_docs.GetAllDocsRequest(
                                    startKey: "l", endKey: "l\uffff"),
                                (json) => json);
                        setState(() {
                          end100Get =
                              DateTime.now().millisecondsSinceEpoch.toString();
                        });
                        print("All Docs Length: ${allDocs.rows.length}");
                        for (int x = 0; x < allDocs.rows.length; x++) {
                          print(allDocs.rows[x].toJson((value) => value));
                        }
                        print(allDocs.toJson((value) => value));
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
                    if (startDesignDoc == "No Started Yet") {
                      await foodb.adapter.createIndex(
                          indexFields: ["name", "no"],
                          ddoc: "name_doc",
                          name: "name_index");
                      setState(() {
                        startDesignDoc =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                      List<all_docs.Row<Map<String, dynamic>>> docs =
                          await foodb.adapter.view("name_doc", "name_index",
                              startKey: "l", endKey: "l\uffff");
                      setState(() {
                        endDesignDoc =
                            DateTime.now().millisecondsSinceEpoch.toString();
                      });
                      for (all_docs.Row doc in docs) {
                        print(doc.toJson((value) => value));
                      }
                      print(docs.length);
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
            ],
          ),
        ),
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
      for (int y = 0; y < 1; y++) {
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
    }

    for (int y = 0; y < 5; y++) {
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
  }
}
