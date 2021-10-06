import 'dart:io';

import 'package:dotenv/dotenv.dart';
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
  Future<Foodb> db(String dbName);
}

class CouchdbTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName) async {
    return getCouchDb('test-$dbName');
  }
}

class InMemoryTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName) async {
    return Foodb.keyvalue(
        dbName: 'test-$dbName', keyValueDb: InMemoryAdapter());
  }
}

Future<Foodb> getCouchDb(String dbName, {bool persist = false}) async {
  HttpOverrides.global = null;
  load('.env');
  var baseUri = env['COUCHDB_LOCAL_URI']!;
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
  }
  return db;
}

final List<Function(FoodbTestContext)> fullTestSuite = [
  ...allDocTest(),
  ...bulkDocTest(),
  ...changeStreamTest(),
  ...deleteTest(),
  ...findTest(),
  ...getTest(),
  ...putTest(),
  ...utilTest(),
];
