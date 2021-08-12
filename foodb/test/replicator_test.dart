import 'dart:io';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/replicator.dart';

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

  Replicator replicator = new Replicator(
      source: getCouchDbAdapter(), target: getCouchDbAdapter(dbName: "a-test"));
  Replicator replicator2 = new Replicator(
      source: getCouchDbAdapter(dbName: "a-test"), target: getCouchDbAdapter());

  test('replicator 2', () async {
    await getCouchDbAdapter(dbName: "a-test").destroy();
    await getCouchDbAdapter(dbName: "a-test").init();

    var fn = expectAsync1((result) {
      print("in fn");
      expect(result, "Completed");
    });

    replicator.replicate(
        live: false,
        timeout: Duration(milliseconds: 500),
        onData: (data) {
          print(data);
          // if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onError: (error, retry) {
          print(error);
          // retry();
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });
  });

  test("put docs", () async {
    PutResponse putResponse = await getCouchDbAdapter(dbName: "adish").put(
        doc: Doc(id: "feedme", model: {"name": "feedmefood", "no": 300}),
        newEdits: false,
        newRev: "1-asdfg");
    expect(putResponse.ok, isTrue);
  });

  test('replicator', () async {
    PutResponse putResponse = await getCouchDbAdapter(dbName: "adish").put(
        doc: Doc(id: "feedme", model: {"name": "feedmefood", "no": 300}),
        newEdits: false,
        newRev: "1-asdfg");
    expect(putResponse.ok, isTrue);

    PutResponse putResponse2 = await getCouchDbAdapter(dbName: "adish").put(
        doc: Doc(
            id: "feedme",
            model: {"name": "feedmecola", "no": 200},
            rev: "1-asdfg"),
        newEdits: false,
        newRev: "2-asdfg");
    expect(putResponse2.ok, isTrue);

    PutResponse putResponse3 = await getCouchDbAdapter(dbName: "adish").put(
        doc: Doc(
            id: "feedme",
            model: {"name": "feedmeburger", "no": 900},
            rev: "1-asdfg"),
        newEdits: false,
        newRev: "2-bbdfg");
    expect(putResponse3.ok, isTrue);

    await getCouchDbAdapter(dbName: "a-test").destroy();
    await getCouchDbAdapter(dbName: "a-test").init();

    //case 1
    //case 2
    await getCouchDbAdapter(dbName: "a-test").put(
        doc: Doc(id: "feedme", model: {"name": "feedmefood", "no": 300}),
        newEdits: false,
        newRev: "1-asdfg");

    // case 3
    await getCouchDbAdapter(dbName: "a-test").put(
        doc: Doc(
            id: "feedme",
            model: {"name": "starvation", "no": 999},
            rev: "1-asdfg"),
        newEdits: false,
        newRev: "2-zzzzz");

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

          //retry();
        },
        onComplete: (result) {
          print("DONE HERE $result");
          fn(result);
        });

    Future.delayed(Duration(seconds: 10)).then((value) => {
          getCouchDbAdapter(dbName: "adish").put(
              doc: Doc(
                  id: "fn2 ultimately last last",
                  model: {"name": "fueffd", "no": 999}))
        });
  });
}
