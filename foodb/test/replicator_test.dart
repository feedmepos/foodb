import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/replicator.dart';
import 'package:http/http.dart';

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String envDbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  getCouchDbAdapter({String? dbName}) {
    return new CouchdbAdapter(
        dbName: dbName ?? envDbName, baseUri: Uri.parse(baseUri));
  }

  getMemoryAdapter() async {
    // return KeyValueAdapter(dbName: dbName, db: InMemoryDatabase());
  }

  //Replicator Between CouchDb
  Replicator replicator = new Replicator(
      source: getCouchDbAdapter(), target: getCouchDbAdapter(dbName: "a-test"));
  Replicator replicator2 = new Replicator(
      source: getCouchDbAdapter(dbName: "a-test"), target: getCouchDbAdapter());

  test('check replicator with 2 couchdb', () async {
    await getCouchDbAdapter(dbName: "a-test").destroy();
    await getCouchDbAdapter(dbName: "a-test").initDb();

    var fn = expectAsync1((result) {
      print("in fn");
      expect(result, "Completed");
    });

    Replicator(source: getCouchDbAdapter(dbName: "fortyk"),target: getCouchDbAdapter(dbName: "adish")).replicate(
        live: false,
        timeout: Duration(milliseconds: 500),
        limit: 5000,
        onData: (data) {
          print(data);
          // if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onError: (error, retry) {
          print(error);
          retry();
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });
  });
  test('check synchronization with 2 couchdb', () async {
    await getCouchDbAdapter(dbName: "a-test").destroy();
    await getCouchDbAdapter(dbName: "a-test").initDb();

    PutResponse putResponse = await getCouchDbAdapter(dbName: "adish").put(
      doc: Doc(
          id: "feedme",
          rev: Rev.fromString("1-asdfg"),
          model: {"name": "feedmefood", "no": 300}),
      newEdits: false,
    );
    expect(putResponse.ok, isTrue);

    PutResponse putResponse2 = await getCouchDbAdapter(dbName: "adish").put(
      doc: Doc(
          id: "feedme",
          model: {"name": "feedmecola", "no": 200},
          rev: Rev.fromString("2-asdfg"),
          revisions: Revisions(start: 2, ids: ["asdfg", "asdfg"])),
      newEdits: false,
    );
    expect(putResponse2.ok, isTrue);

    PutResponse putResponse3 = await getCouchDbAdapter(dbName: "adish").put(
      doc: Doc(
          id: "feedme",
          model: {"name": "feedmeburger", "no": 900},
          rev: Rev.fromString("2-bbdfg"),
          revisions: Revisions(ids: ["bbdfg", "asdfg"], start: 2)),
      newEdits: false,
    );
    expect(putResponse3.ok, isTrue);

    await getCouchDbAdapter(dbName: "a-test").destroy();
    await getCouchDbAdapter(dbName: "a-test").initDb();

    //case 1
    //case 2
    await getCouchDbAdapter(dbName: "a-test").put(
      doc: Doc(
          id: "feedme",
          rev: Rev.fromString("1-asdfg"),
          model: {"name": "feedmefood", "no": 300}),
      newEdits: false,
    );

    // case 3
    await getCouchDbAdapter(dbName: "a-test").put(
      doc: Doc(
          id: "feedme",
          model: {"name": "starvation", "no": 999},
          rev: Rev.fromString("2-zzzzz"),
          revisions: Revisions(ids: ["zzzzz", "asdfg"], start: 2)),
      newEdits: false,
    );

    // var fn3 = expectAsync1((result) {
    //   print(result);
    //   expect(result, isInstanceOf<Exception>());
    // });

    // var fn2 = expectAsync1((result) {
    //   // print("in fn2");
    //   print(result == "One Cycle Completed");
    //   replicator.cancelStream();

    //   expect(result, equals("One Cycle Completed"));
    // });

    var fn4 = expectAsync1((result) {
      expect(result, "Completed");
    });

    var fn = expectAsync1((result) {
      // print("in fn");
      print(result == "Completed");
      expect(result, equals("Completed"));

      replicator2.replicate(
          live: false,
          timeout: Duration(milliseconds: 500),
          onData: (data) {
            print(data);
          },
          onError: (error, retry) {
            print(error);
            retry();
          },
          onComplete: (result) {
            print(result);
            fn4(result);
          });
    });

    int count = 0;

    replicator.replicate(
        live: false,
        limit: 5,
        timeout: Duration(milliseconds: 500),
        onData: (data) {
          print(data);
          if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   // fn2(data);
          // }
        },
        onError: (error, retry) {
          print(error);
          print("error ${error.runtimeType}");
          //if (count == 2)
          //fn3(error);

          retry();
        },
        onComplete: (result) {
          print("DONE HERE $result");
          fn(result);
        });

    // Future.delayed(Duration(seconds: 10)).then((value) => {
    //       getCouchDbAdapter()
    //           .put(doc: Doc(id: "fn2", model: {"name": "fueffd", "no": 999}))
    //     });
  });
  test("check replicator from memoryDb to couchdb", () async {
    final couchdb = getCouchDbAdapter(dbName: "a-test");
    await couchdb.destroy();
    await couchdb.initDb();

    final memorydb = await getMemoryAdapter();
    await memorydb.put(doc: Doc(id: "1", model: {"name": "abc", "no": 123}));
    await memorydb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-b"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);
    await memorydb.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
    await memorydb.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

    Replicator replicator = new Replicator(source: memorydb, target: couchdb);

    // var fn = expectAsync1((result) {
    //   print("in fn");
    //   expect(result, "Completed");
    // });

    var fn = expectAsync1((result) {
      print("in continuous");
      replicator.cancelAll();

      expect(result, equals("One Cycle Completed"));
    });

    int count = 0;
    replicator.replicate(
        live: true,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e);
          retry();
        },
        onData: (data) {
          print(data);
          if (data == "One Cycle Completed") ++count;
          if (count == 2) {
            fn(data);
          }
        },
        onComplete: (result) {
          print(result);
          //fn(result);
        });

    await Future.delayed(Duration(seconds: 10)).then((value) => {
          memorydb.put(doc: Doc(id: "test1", model: {"name": "a", "no": 999}))
        });
    await Future.delayed(Duration(seconds: 2)).then((value) => {
          memorydb.put(doc: Doc(id: "test2", model: {"name": "b", "no": 999}))
        });
  });
  test("check replicator from couchdb to memorydb", () async {
    final couchdb = getCouchDbAdapter(dbName: "a-test");
    final memorydb = await getMemoryAdapter();

    await couchdb.destroy();
    await couchdb.initDb();
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

    Replicator replicator = new Replicator(source: couchdb, target: memorydb);

    // var fn = expectAsync1((result) {
    //   print("in fn");
    //   expect(result, "Completed");
    // });

    var fn = expectAsync1((result) {
      print("in continuous");
      replicator.cancelAll();

      expect(result, equals("One Cycle Completed"));
    });

    int count = 0;
    replicator.replicate(
        live: true,
        timeout: Duration(milliseconds: 500),
        onError: (e, retry) {
          print(e);
          //retry();
        },
        onData: (data) {
          print(data);
          if (data == "One Cycle Completed") ++count;
          if (count == 2) {
            fn(data);
          }
        },
        onComplete: (result) {
          print(result);
          //fn(result);
        });
    await Future.delayed(Duration(seconds: 5)).then((value) => {
          couchdb.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
        });
    await Future.delayed(Duration(seconds: 2)).then((value) => {
          couchdb.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
        });

    // print((await memorydb.allDocs(GetAllDocsRequest(), (json) => json))
    //     .toJson((value) => value));

    Future.delayed(Duration(seconds: 2))
        .then(expectAsync1((value) => expect(1 + 1, 2)));
  });
  test("check replicator from couchdb to memorydb with changeStream", () async {
    final memorydb = await getMemoryAdapter();
    final couchdb = getCouchDbAdapter(dbName: "a-test");

    await couchdb.destroy();
    await couchdb.initDb();
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

    Replicator replicator = new Replicator(source: couchdb, target: memorydb);

    // var fn = expectAsync1((result) {
    //   print("in fn");
    //   expect(result, "Completed");
    // });

    var fn = expectAsync1((result) async {
      await replicator.cancelAll();
      expect(result, equals("One Cycle Completed"));
    });

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
          if (data == "One Cycle Completed") ++count;
          if (count == 2) {
            fn(data);
          }
        },
        onComplete: (result) {
          print(result);
          //fn(result);
        });
    int count2 = 0;
    var fc1 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("1"));
    });

    var fc2 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("1"));
    });

    var fc3 = expectAsync1((ChangeResult changeResult) {
      print("Verify: ${changeResult.toJson()}");
      expect(changeResult.id, equals("2"));
    });

    var fc4 = expectAsync1((ChangeResult changeResult) {
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

    ChangesStream changesStream = await memorydb
        .changesStream(ChangeRequest(feed: ChangeFeed.continuous));
    changesStream.listen(
        onResult: expectAsync1((result) {
      count2++;
      print("RESULT ${result.toJson()}");
      if (count2 == 1)
        fc1(result);
      else if (count2 == 2)
        fc2(result);
      else if (count2 == 3)
        fc3(result);
      else if (count2 == 4) fc4(result);
      // else if (count2 == 5) fc5(result);
    }, count: 5));
  });
  test("check replicator from memoryDb to couchDb with changeStream", () async {
    final couchdb = getCouchDbAdapter(dbName: "a-test");
    await couchdb.destroy();
    await couchdb.initDb();

    final memorydb = await getMemoryAdapter();
    await memorydb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-b"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);

    await memorydb.put(
        doc: Doc(
            id: "1",
            rev: Rev.fromString("1-a"),
            model: {"name": "abc", "no": 123}),
        newEdits: false);
    await memorydb.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
    await memorydb.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

    Replicator replicator = new Replicator(source: memorydb, target: couchdb);

    // var fn = expectAsync1((result) {
    //   print("in fn");
    //   expect(result, "Completed");
    // });

    var fn = expectAsync1((result) async {
      await replicator.cancelAll();
      expect(result, equals("One Cycle Completed"));
    });

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
          if (data == "One Cycle Completed") ++count;
          if (count == 2) {
            fn(data);
          }
        },
        onComplete: (result) {
          print(result);
          //fn(result);
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
          memorydb.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
        });
    Future.delayed(Duration(seconds: 10)).then((value) => {
          memorydb.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
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
    }, count: 4));
  });
}
