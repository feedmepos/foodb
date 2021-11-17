import 'dart:io';
import 'dart:math';

import 'package:dotenv/dotenv.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:test/test.dart';
import 'package:foodb/foodb.dart';

import './src/test/find_test.dart';
import './src/test/all_doc_Test.dart';
import './src/test/bulk_doc_test.dart';
import './src/test/change_stream_test.dart';
import './src/test/delete_test.dart';
import './src/test/get_test.dart';
import './src/test/put_test.dart';
import './src/test/util_test.dart';

export './src/test/find_benchmark_test.dart' show findBenchmarkTest;
export './src/test/find_test.dart' show findTest;
export './src/test/all_doc_Test.dart' show allDocTest;
export './src/test/bulk_doc_test.dart' show bulkDocTest;
export './src/test/change_stream_test.dart' show changeStreamTest;
export './src/test/delete_test.dart' show deleteTest;
export './src/test/get_test.dart' show getTest;
export './src/test/put_test.dart' show putTest;
export './src/test/util_test.dart' show utilTest;
export './src/test/replicate_test.dart' show replicateTest;
export './src/test/replicate_benchmark_test.dart' show replicateBenchmarkTest;

abstract class FoodbTestContext {
  Future<Foodb> db(String dbName, {bool? persist, String prefix});
}

class CouchdbTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix = 'test-'}) async {
    return getCouchDb('$prefix$dbName', persist: persist ?? false);
  }
}

class InMemoryTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix = 'test-'}) async {
    var inMemoryDb = Foodb.keyvalue(
        dbName: '$prefix$dbName', keyValueDb: KeyValueAdapter.inMemory());
    await inMemoryDb.initDb();
    return inMemoryDb;
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<Foodb> getCouchDb(String dbName, {bool persist = false}) async {
  HttpOverrides.global = MyHttpOverrides();
  load('.env');
  var baseUri = env['COUCHDB_TEST_URI']!;
  var db = Foodb.couchdb(dbName: dbName, baseUri: Uri.parse(baseUri));
  if (!persist) {
    try {
      await db.info();
      await db.destroy();
    } catch (err) {
      //
    }
    await db.initDb();
    addTearDown(() async {
      await db.destroy();
    });
  } else {
    await db.initDb();
  }
  return db;
}

Map<String, dynamic> _getObject(int keyCount, Function() val) {
  return Map<String, dynamic>.from(List.generate(
    keyCount,
    (index) => 'field$index',
  ).asMap().map(
        (key, value) => MapEntry(
          value,
          val(),
        ),
      ));
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
var _rnd = Random();
String _getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

getDoc(String id) {
  return Doc(id: id, model: _getObject(0, () => null));
}

getLargeDoc(String id) {
  return Doc(
    id: id,
    model: _getObject(
      30,
      () => _getObject(
        3,
        () => _getObject(
          2,
          () => _getObject(
            1,
            () => _getRandomString(30).split(''),
          ),
        ),
      ),
    ),
  );
}

final List<Function(FoodbTestContext)> foodbFullTestSuite = [
  ...allDocTest(),
  ...bulkDocTest(),
  ...changeStreamTest(),
  ...deleteTest(),
  ...findTest(),
  ...getTest(),
  ...putTest(),
  ...utilTest(),
];
