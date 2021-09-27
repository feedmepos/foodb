import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/foodb.dart';

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

class AdapterTestContext {
  Foodb? db;
}

testEachAdapter(String dbName, void Function(AdapterTestContext) test) {
  group('test for each db', () {
    final context = AdapterTestContext();
    setUpAll(() async {
      context.db = await getCouchDbAdapter(dbName);
    });
    test(context);
  });
}
