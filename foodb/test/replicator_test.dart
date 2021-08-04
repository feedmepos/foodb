import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
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

  test('replicator', () async {
    await getCouchDbAdapter(dbName: "a-test").destroy();
    await getCouchDbAdapter(dbName: "a-test").init();

    var fn = expectAsync1((result) {
      expect(result, "Completed");
    });

    // var fn = expectAsync1((result) {
    //   expect(result, "One Cycle Completed");
    // });

    int count = 0;
    replicator.replicate(
        live: false,
        timeout: Duration(milliseconds: 500),
        onData: (data) {
          print(data);
          if (data == "One Cycle Completed") ++count;
          // if (count == 2) {
          //   fn(data);
          // }
        },
        onError: (error, retry) {
          print(error);
          //retry();
        },
        onComplete: (result) {
          print(result);
          fn(result);
        });

    Future.delayed(Duration(seconds: 10)).then((value) => {
          getCouchDbAdapter(dbName: "adish")
              .put(doc: Doc(id: "blackberry", model: {"name": "fuff"}))
        });
  });
}
