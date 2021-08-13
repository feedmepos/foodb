import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';

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

  test('JSDesignDocView() ', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: "b-1");
    Doc<DesignDoc>? doc = await couchDb.fetchDesignDoc(id: "_design/test");
    print(doc?.toJson((value) => value.toJson()));
  });

  test('QueryDesignDocView() ', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: "b-1");
    Doc<DesignDoc>? doc =
        await couchDb.fetchDesignDoc(id: "_design/type_user_no");
    print(doc?.toJson((value) => value.toJson()));
  });

  test('AllDocsDesignDocView() ', () async {});
}
