import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/replicator.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");

  String envDbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String benchDbName = dotenv.env['COUCHDB_DB_BENCHMARKS'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;
  String localUri = dotenv.env['COUCHDB_LOCAL_URI'] as String;
  String dbName = dotenv.env['OBJECTBOX_DB_NAME'] as String;

  getCouchDbAdapter({String? dbName}) {
    return new CouchdbAdapter(
        dbName: dbName ?? envDbName, baseUri: Uri.parse(baseUri));
  }

  getLocalCouchDbAdapter({String? dbName}) {
    return new CouchdbAdapter(
        dbName: dbName ?? benchDbName, baseUri: Uri.parse(localUri));
  }

  getObjectBox() {
    ObjectBox objectBox = new ObjectBox();
    return objectBox;
  }

  test('check replicator with 2 couchdb', () async {
    await getLocalCouchDbAdapter(dbName: "adish").destroy();
    await getLocalCouchDbAdapter(dbName: "adish").init();

    var fn = expectAsync1((result) {
      print("in fn");
      expect(result, "Completed");
    });

    Replicator(
            source: getLocalCouchDbAdapter(dbName: "restaurant"),
            target: getLocalCouchDbAdapter(dbName: "adish"))
        .replicate(
            live: false,
            timeout: Duration(milliseconds: 500),
            limit: 5000,
            onData: (data) {
              //print(data);
            },
            onError: (error, retry) {
              print(error);
            },
            onComplete: (result) {
              print(result);
              fn(result);
            });
  }, timeout: Timeout.none);
  test("generate 40k DB", () async {
    final couchdb = getLocalCouchDbAdapter(dbName: "fortyk");
    // await couchdb.destroy();
    // await couchdb.init();

    List<Doc<Map<String, dynamic>>> docs = [];
    for (int x = 30000; x < 40000; x++) {
      docs.add(Doc(id: "$x", model: {"name": "$x nasi lemak", "no": x}));
      print(x);
    }
    await couchdb.bulkDocs(body: docs, newEdits: true);
  }, timeout: Timeout.none);
  test("generate 5k DB", () async {
    final couchdb = getCouchDbAdapter(dbName: "fthousand");
    await couchdb.destroy();
    await couchdb.init();

    List<Doc<Map<String, dynamic>>> docs = [];
    for (int x = 0; x < 5000; x++) {
      docs.add(Doc(id: "$x", model: {"name": "$x nasi lemak", "no": x}));
      print(x);
    }
    await couchdb.bulkDocs(body: docs, newEdits: true);
  }, timeout: Timeout.none);
  test("check replicator from objectBox to couchdb", () async {
    final couchdb = getCouchDbAdapter(dbName: "a-test");
    await couchdb.destroy();
    await couchdb.init();

    final object = await getObjectBox();
    await object.deleteDatabase();

    final objectBox = new KeyValueAdapter(dbName: dbName, db: object);
    await objectBox.put(doc: Doc(id: "1", model: {"name": "abc", "no": 123}));
    await objectBox.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-b"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);
    await objectBox.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
    await objectBox.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

    Replicator replicator = new Replicator(source: objectBox, target: couchdb);

    var fn = expectAsync1((result) async {
      print("in fn");
      expect(result, "Completed");
      GetAllDocsResponse response =
          await couchdb.allDocs(GetAllDocsRequest(), (json) => json);
      expect(response.rows.length, 3);

      // var fn = expectAsync1((result) {
      //   print("in continuous");
      //   replicator.cancelAll();

      //   expect(result, equals("One Cycle Completed"));
    });

    int count = 0;
    replicator.replicate(
        live: false,
        limit: 2,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e);
          //retry();
        },
        onData: (data) {
          print(data);
          // if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });

    // await Future.delayed(Duration(seconds: 10)).then((value) => {
    //       objectBox.put(doc: Doc(id: "test1", model: {"name": "a", "no": 999}))
    //     });
    // await Future.delayed(Duration(seconds: 2)).then((value) => {
    //       objectBox.put(doc: Doc(id: "test2", model: {"name": "b", "no": 999}))
    //     });
  });
  test("check replicator from couchdb to objectBox", () async {
    final couchdb = getCouchDbAdapter();
    final object = getObjectBox();
    await object.deleteDatabase();

    final objectBox = await KeyValueAdapter(db: object, dbName: dbName);
    await couchdb.destroy();
    await couchdb.init();
    await couchdb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-b"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);

    await couchdb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-a"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);
    await couchdb.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
    await couchdb.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

    Replicator replicator = new Replicator(source: couchdb, target: objectBox);

    var fn = expectAsync1((result) async {
      print("in fn");
      expect(result, "Completed");

      GetAllDocsResponse allDocsResponse =
          await objectBox.allDocs(GetAllDocsRequest(), (json) => json);
      print(allDocsResponse.toJson((value) => value));
      expect(allDocsResponse.rows.length, equals(3));
      expect(result, "Completed");
    });

    // var fn = expectAsync1((result) {
    //   print("in continuous");
    //   replicator.cancelAll();

    //   expect(result, equals("One Cycle Completed"));
    // });

    int count = 0;
    replicator.replicate(
        live: false,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e);
          //retry();
        },
        onData: (data) {
          print(data);
          // if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });
    await Future.delayed(Duration(seconds: 5)).then((value) => {
          couchdb.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
        });
    await Future.delayed(Duration(seconds: 2)).then((value) => {
          couchdb.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
        });

    // print((await objectBox.allDocs(GetAllDocsRequest(), (json) => json))
    //     .toJson((value) => value));
  });
  test("check replicator from couchdb to objectBox with changeStream",
      () async {
    final object = getObjectBox();
    await object.deleteDatabase();

    final objectBox = KeyValueAdapter(dbName: dbName, db: object);
    final couchdb = getCouchDbAdapter(dbName: "a-test");

    await couchdb.destroy();
    await couchdb.init();
    await couchdb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-b"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);

    await couchdb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-a"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);
    await couchdb.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
    await couchdb.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

    Replicator replicator = new Replicator(source: couchdb, target: objectBox);

    var fn = expectAsync1((result) {
      print("in fn");
      expect(result, "Completed");
    });

    // var fn = expectAsync1((result) async {
    //   await replicator.cancelAll();
    //   expect(result, equals("One Cycle Completed"));
    // });

    int count = 0;
    replicator.replicate(
        live: false,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e);
          //retry();
        },
        onData: (data) {
          print(data);
          // if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });
    int count2 = 0;
    var fc1 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("1"));
    });

    var fc2 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("2"));
    });

    var fc3 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("3"));
    });

    // var fc5 = expectAsync1((ChangeResult changeResult) {
    //   print("Verify: ${changeResult.toJson()}");
    //   expect(changeResult.id, equals("4"));
    // });

    Future.delayed(Duration(seconds: 5)).then((value) => {
          couchdb.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
        });
    Future.delayed(Duration(seconds: 10)).then((value) => {
          couchdb.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
        });

    ChangesStream changesStream = await objectBox
        .changesStream(ChangeRequest(feed: ChangeFeed.continuous));
    changesStream.listen(
        onResult: expectAsync1((result) {
      count2++;
      print("RESULT ${result.toJson()}");
      if (count2 == 1)
        fc1(result);
      else if (count2 == 2)
        fc2(result);
      else if (count2 == 3) fc3(result);
      // else if (count2 == 4) fc4(result);
      // else if (count2 == 5) fc5(result);
    }, count: 3));
  });
  test("check replicator from objectBox to couchDb with changeStream",
      () async {
    final couchdb = getCouchDbAdapter();
    await couchdb.destroy();
    await couchdb.init();

    final object = await getObjectBox();
    final objectBox = new KeyValueAdapter(dbName: dbName, db: object);

    await objectBox.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-b"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);

    await objectBox.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-a"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);
    await objectBox.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
    await objectBox.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

    Replicator replicator = new Replicator(source: objectBox, target: couchdb);

    var fn = expectAsync1((result) async {
      print("in fn");
    });

    // var fn = expectAsync1((result) async {
    //   await replicator.cancelAll();
    //   expect(result, equals("One Cycle Completed"));
    // });

    int count = 0;
    replicator.replicate(
        live: false,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e);
          //retry();
        },
        onData: (data) {
          //print(data);
          // if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });
    int count2 = 0;

    var fc1 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("1"));
    });

    var fc2 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("2"));
    });

    var fc3 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("3"));
    });

    // var fc4 = expectAsync1((ChangeResult changeResult) {
    //   print("Verify: ${changeResult.toJson()}");
    //   expect(changeResult.id, equals("4"));
    // });

    Future.delayed(Duration(seconds: 5)).then((value) => {
          objectBox.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
        });
    Future.delayed(Duration(seconds: 10)).then((value) => {
          objectBox.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
        });

    ChangesStream changesStream =
        await couchdb.changesStream(ChangeRequest(feed: ChangeFeed.continuous));
    changesStream.listen(
        onResult: expectAsync1((result) {
      count2++;
      print("RESULT ${result.toJson()}");
      if (count2 == 1)
        fc1(result);
      else if (count2 == 2)
        fc2(result);
      else if (count2 == 3) fc3(result);
      // else if (count2 == 4) fc4(result);
    }, count: 3));
  });
  test("couchdb check missed id", () async {
    final localCouch = getLocalCouchDbAdapter(dbName: 'restaurant');
    GetAllDocsResponse response = await localCouch.allDocs(
        GetAllDocsRequest(includeDocs: true), (json) => json);
    List<String> couchIds = response.rows.map((e) => e.doc!.id).toList();
    
    final box = new ObjectBox();
    ReadResult response2 = await box.read(DocDataType());
    List<String> ids = response2.docs.keys.toList();

    print("check ids");
    List<String> missed = [];
    ids.forEach(((e) {
      if (!couchIds.contains(e)) {
        missed.add(e);
        print(e);
      }
    }));

    print("response.totalRows: ${response.totalRows}");
    print("response2.totalRows: ${response2.totalRows}");
    print("response.rows.length: ${response.rows.length}");
    print("response2.rows.length: ${response2.docs.length}");

    expect(missed.length, 0);
  }, timeout: Timeout.none);
  test("Benchmark: Replication From Couchdb to ObjectBox with 40K docs ",
      () async {
    final couchdb = getLocalCouchDbAdapter(dbName: 'fortyk');

    final object = await getObjectBox();
    await object.deleteDatabase();

    final objectBox = new KeyValueAdapter(dbName: 'fortyk', db: object);

    var fn = expectAsync1((result) async {
      print("in fn");
      int size = await object.tableSize(DocDataType());
      expect(size, 40000);
    });

    // var fn2 = expectAsync0(() async {
    //   objectBox
    //       .allDocs(GetAllDocsRequest(), (json) => json)
    //       .then((value) => expect(value.rows.length, equals(40000)));
    // });

    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    Replicator(source: couchdb, target: objectBox).replicate(
        live: false,
        limit: 5000,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e.toString());
        },
        onData: (data) {
          //print(data);
        },
        onComplete: (result) async {
          stopwatch.stop();
          print("Timetaken: ${stopwatch.elapsedMilliseconds}");
          fn(result);
        });
  }, timeout: Timeout.none);

  test("check total docs replicated from couchdb", () async {
    final objectBox = KeyValueAdapter(dbName: "fortyk", db: getObjectBox());
    final GetAllDocsResponse response =
        await objectBox.allDocs(GetAllDocsRequest(), (json) => json);
    print(response.toJson((value) => value));
    expect(response.totalRows, equals(40000));
  }, timeout: Timeout.none);

  test("Benchmark: Replication From ObjectBox to CouchDb with 40K docs ",
      () async {
    final couchdb = getLocalCouchDbAdapter(dbName: "fromobjectbox");
    await couchdb.destroy();
    await couchdb.init();

    final objectBox =
        new KeyValueAdapter(dbName: 'restaurant', db: getObjectBox());

    var fn = expectAsync1((result) {
      print("in fn");
      expect(result, "Completed");
    });

    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    Replicator(source: objectBox, target: couchdb).replicate(
        live: false,
        limit: 5000,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e.toString());
        },
        onData: (data) {
          print(data);
        },
        onComplete: (result) async {
          stopwatch.stop();
          print("Timetaken: ${stopwatch.elapsedMilliseconds}");
          fn(result);
        });
  }, timeout: Timeout.none);
  test("check total docs replicated from objectbox", () async {
    final objectBox = KeyValueAdapter(dbName: "tenk", db: getObjectBox());
    final GetAllDocsResponse response =
        await objectBox.allDocs(GetAllDocsRequest(), (json) => json);
    print(response.toJson((value) => value));
    expect(response.totalRows, equals(40000));
  }, timeout: Timeout.none);
}
