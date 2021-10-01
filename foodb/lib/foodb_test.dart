import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import './test/find_test.dart';
import './test/all_doc_Test.dart';
import './test/bulk_doc_test.dart';
import './test/change_stream_test.dart';
import './test/delete_test.dart';
import './test/get_test.dart';
import './test/put_test.dart';
import './test/util_test.dart';

export './test/find_test.dart' show findTest;
export './test/all_doc_Test.dart' show allDocTest;
export './test/bulk_doc_test.dart' show bulkDocTest;
export './test/change_stream_test.dart' show changeStreamTest;
export './test/delete_test.dart' show deleteTest;
export './test/get_test.dart' show getTest;
export './test/put_test.dart' show putTest;
export './test/util_test.dart' show utilTest;
export './test/replicate_test.dart' show replicateTest;
export './test/replicate_benchmark_test.dart' show replicateBenchmarkTest;

abstract class FoodbTestContext {
  Future<Foodb> db(String dbName);
}

class CouchdbTestContext extends FoodbTestContext {
  Future<Foodb> db(String dbName) async {
    return getCouchDb('test-$dbName');
  }
}

class InMemoryTestContext extends FoodbTestContext {
  Future<Foodb> db(String dbName) async {
    return Foodb.keyvalue(
        dbName: 'test-$dbName', keyValueDb: InMemoryAdapter());
  }
}

Future<Foodb> getCouchDb(String dbName, {bool persist = false}) async {
  HttpOverrides.global = null;
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  String baseUri = dotenv.env['COUCHDB_LOCAL_URI'] as String;
  var db = Foodb.couchdb(dbName: dbName, baseUri: Uri.parse(baseUri));
  if (!persist) {
    try {
      await db.info();
      await db.destroy();
    } catch (err) {}
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

void main() {
  group('couchdb', () {
    final ctx = CouchdbTestContext();
    fullTestSuite.asMap().keys.forEach((key) {
      final test = fullTestSuite[key];
      test(ctx);
    });
  });

  group('in memory', () {
    final ctx = InMemoryTestContext();
    fullTestSuite.asMap().keys.forEach((key) {
      final test = fullTestSuite[key];
      test(ctx);
    });
  });
}
