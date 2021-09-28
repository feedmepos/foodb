import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/foodb.dart';

import 'all_doc_Test.dart';
import 'bulk_doc_test.dart';
import 'change_stream_test.dart';
import 'delete_test.dart';
import 'find_test.dart';
import 'get_test.dart';
import 'put_test.dart';
import 'util_test.dart';
import 'view_test.dart';

abstract class AdapterTestContext {
  Future<Foodb> db(String dbName);
}

class CouchdbAdapterTestContext extends AdapterTestContext {
  Future<Foodb> db(String dbName) async {
    return getCouchDbAdapter(dbName);
  }
}

class InMemoryAdapterTestContext extends AdapterTestContext {
  Future<Foodb> db(String dbName) async {
    return Foodb.inMemoryDb(dbName: dbName);
  }
}

Future<CouchdbAdapter> getCouchDbAdapter(String dbName,
    {bool persist = false}) async {
  HttpOverrides.global = null;
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;
  var db = new CouchdbAdapter(dbName: dbName, baseUri: Uri.parse(baseUri));
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

void main() {
  final tests = [
    ...findTest(),
    ...changeStreamTest(),
    ...getTest(),
    ...putTest(),
    ...utilTest(),
    ...viewTest(),
    ...bulkDocTest(),
    ...deleteTest(),
    ...allDocTest()
  ];
  group('couchdb adapter', () {
    final ctx = CouchdbAdapterTestContext();
    tests.asMap().keys.forEach((key) {
      final test = tests[key];
      test(ctx);
    });
  });

  group('in memory adapter', () {
    final ctx = InMemoryAdapterTestContext();
    tests.asMap().keys.forEach((key) {
      final test = tests[key];
      test(ctx);
    });
  });
}
