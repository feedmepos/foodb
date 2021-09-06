import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb_sqflite_adapter/sqlite_database/foodb_sqflite_database.dart';
import 'package:foodb_sqflite_adapter/sqlite_database/sqlite_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['SQLITE_DB_NAME'] as String;

  sqfliteFfiInit();
  var factory = databaseFactoryFfi;
  await factory.deleteDatabase(
      p.join((await getApplicationDocumentsDirectory()).path, 'db'));
  Database db = await factory.openDatabase(
      p.join((await getApplicationDocumentsDirectory()).path, 'db'),
      options: OpenDatabaseOptions(
          version: 1, onCreate: SqliteProvider(dbName: dbName).initDB));

  final SqliteDatabase sqlDb = new SqliteDatabase(dbName: dbName, database: db);
  test("crud test", () async {
    //put / create
    bool putResponse = await sqlDb.put("doc_table",
        id: "1",
        object: Doc<Map<String, dynamic>>(
            id: "1",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    expect(putResponse, isTrue);

    //get
    Map<String, dynamic>? doc = await sqlDb.get("doc_table", id: "1");
    expect(doc, isNotNull);
  });
  test("read", () async {
    await db.delete("doc_table");
    bool putResponse = await sqlDb.put("doc_table",
        id: "a",
        object: Doc<Map<String, dynamic>>(
            id: "a",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse2 = await sqlDb.put("doc_table",
        id: "ab",
        object: Doc<Map<String, dynamic>>(
            id: "ab",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse3 = await sqlDb.put("doc_table",
        id: "bc",
        object: Doc<Map<String, dynamic>>(
            id: "bc",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    ReadResult readResult =
        await sqlDb.read("doc_table", startkey: "a", endkey: "a\uffff");
    expect(readResult.docs.length, equals(2));
  });
  test("read by only startkey / only endkey", () async {
    //await db.delete("doc_table");
    bool putResponse = await sqlDb.put("doc_table",
        id: "ll8bylhis5hy61jamk5qwkrgasdj4d0",
        object: Doc<Map<String, dynamic>>(
            id: "ll8bylhis5hy61jamk5qwkrgasdj4d0",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse2 = await sqlDb.put("doc_table",
        id: "lc4auplxl6lneniwd7m5bfgzyoodo32",
        object: Doc<Map<String, dynamic>>(
            id: "lc4auplxl6lneniwd7m5bfgzyoodo32",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse3 = await sqlDb.put("doc_table",
        id: "xpxhnb2kyb09j9l6f5s822df1fy47ji",
        object: Doc<Map<String, dynamic>>(
            id: "bc",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    ReadResult readResult =
        await sqlDb.read("doc_table", startkey: "l", endkey: "l\uffff");
    expect(readResult.docs.length, equals(2));
  });
}
