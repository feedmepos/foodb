import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_sqlite_adapter/foodb_sqlite_database.dart';
import 'package:foodb_sqlite_adapter/sqlite_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  //await dotenv.load(fileName: ".env");
  //String dbName = dotenv.env['SQLITE_DB_NAME'] as String;
  String dbName = "test";
  sqfliteFfiInit();
  var factory = databaseFactoryFfi;

  getDb() async {
    await factory.deleteDatabase(
        p.join((await getApplicationDocumentsDirectory()).path, 'db'));
    Database db = await factory.openDatabase(
        p.join((await getApplicationDocumentsDirectory()).path, 'db'),
        options: OpenDatabaseOptions(
            version: 1, onCreate: SqliteProvider(dbName: dbName).initDB));
    return new SqliteDatabase(dbName: dbName, database: db);
  }

  test("crud test", () async {
    //put / create
    final sqlDb = await getDb();
    bool putResponse = await sqlDb.put("doc_table",
        key: "1",
        object: Doc<Map<String, dynamic>>(
            id: "1",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    expect(putResponse, isTrue);

    //get
    Map<String, dynamic>? doc = await sqlDb.get("doc_table", key: "1");
    expect(doc, isNotNull);
  });

  test("put doc with text containing symobl like \"-\" or \"_\"", () async {
    final sqlDb = await getDb();

    await sqlDb.put("a", key: "1-_1", object: {"rev": "1-1"});
    Map<String, dynamic>? value = await sqlDb.get("a", key: "1-_1");
    expect(value, isNotNull);

    await sqlDb.put("a", key: "1-_1", object: {"rev": "1-2"});
    Map<String, dynamic>? value2 = await sqlDb.get("a", key: "1-_1");
    expect(value2?["rev"], equals("1-2"));
  });

  test("read()", () async {
    final sqlDb = await getDb();
    bool putResponse = await sqlDb.put("doc_table",
        key: "a",
        object: Doc<Map<String, dynamic>>(
            id: "a",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse2 = await sqlDb.put("doc_table",
        key: "ab",
        object: Doc<Map<String, dynamic>>(
            id: "ab",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse3 = await sqlDb.put("doc_table",
        key: "bc",
        object: Doc<Map<String, dynamic>>(
            id: "bc",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    ReadResult readResult =
        await sqlDb.read("doc_table", startkey: "a", endkey: "a\uffff");
    expect(readResult.docs.length, equals(2));
  });

  test("read() with startkey / endkey only", () async {
    final sqlDb = await getDb();

    bool putResponse = await sqlDb.put("doc_table",
        key: "ll8bylhis5hy61jamk5qwkrgasdj4d0",
        object: Doc<Map<String, dynamic>>(
            id: "ll8bylhis5hy61jamk5qwkrgasdj4d0",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse2 = await sqlDb.put("doc_table",
        key: "lc4auplxl6lneniwd7m5bfgzyoodo32",
        object: Doc<Map<String, dynamic>>(
            id: "lc4auplxl6lneniwd7m5bfgzyoodo32",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    bool putResponse3 = await sqlDb.put("doc_table",
        key: "xpxhnb2kyb09j9l6f5s822df1fy47ji",
        object: Doc<Map<String, dynamic>>(
            id: "bc",
            model: {"name": "abc", "no": 123}).toJson((value) => value));
    ReadResult readResult =
        await sqlDb.read("doc_table", startkey: "l", endkey: "l\uffff");
    expect(readResult.docs.length, equals(2));
  });

  test("allDocs() with startKey and endKey", () async {
    var adapter = KeyValueAdapter(dbName: dbName, db: await getDb());

    await adapter.put(
        doc: Doc<Map<String, dynamic>>(
            id: "a",
            rev: Rev.fromString("1-a"),
            model: {"name": "a", "no": 999}),
        newEdits: false);
    await adapter.put(
        doc: Doc<Map<String, dynamic>>(
            id: "b",
            rev: Rev.fromString("1-b"),
            model: {"name": "b", "no": 999}),
        newEdits: false);
    await adapter.put(
        doc: Doc<Map<String, dynamic>>(
            id: "c",
            rev: Rev.fromString("1-c"),
            model: {"name": "c", "no": 999}),
        newEdits: false);
    GetAllDocsResponse<Map<String, dynamic>> docs = await adapter.allDocs(
        GetAllDocsRequest(startkey: "a", endkey: "b\uffff"), (json) => json);
    print(docs.toJson((value) => value));
    expect(docs.rows.length, equals(2));
  });

  test("alldocs()", () async {
    final sqlDb = await getDb();
    final db = KeyValueAdapter(dbName: dbName, db: sqlDb);

    for (int x = 0; x < 100; x++) {
      await db.put(doc: Doc(id: "$x", model: {"name": "a", "no": 99}));
    }
    GetAllDocsResponse response = await db.allDocs<Map<String, dynamic>>(
        GetAllDocsRequest(
          startkey: "1",
          startKeyDocId: "2",
        ),
        (json) => json);
    print("alldocs1 ${response.toJson((value) => value)}");
    expect(response.rows.length, 88);
    expect(response, isNotNull);

    GetAllDocsResponse response2 = await db.allDocs<Map<String, dynamic>>(
        GetAllDocsRequest(startkey: "1", endkey: "1\uffff"), (json) => json);
    print("alldocs2 ${response2.toJson((value) => value)}");
    expect(response2.totalRows, 100);
    expect(response2.rows.length, 11);

    GetAllDocsResponse response3 = await db.allDocs<Map<String, dynamic>>(
        GetAllDocsRequest(startkey: "1", endkey: "1\uffff"), (json) => json);
    print("alldocs3 ${response3.toJson((value) => value)}");
    expect(response3.totalRows, 100);
    expect(response3.rows.length, 11);
  });

  test("view()", () async {
    final sqlDb = await getDb();
    final sqlAdapter = KeyValueAdapter(dbName: dbName, db: sqlDb);
    for (int x = 0; x < 100; x++) {
      await sqlAdapter.put(doc: Doc(id: "$x", model: {"name": "a", "no": 99}));
    }
    //"-" is not allowed as index name
    IndexResponse indexResponse = await sqlAdapter.createIndex(
        indexFields: ["name", "no"], ddoc: "name_view", name: "name_index");
    expect(indexResponse, isNotNull);

    Doc<Map<String, dynamic>>? doc =
        await sqlAdapter.get(id: indexResponse.id, fromJsonT: (json) => json);
    print(doc?.toJson((value) => value));
    expect(doc, isNotNull);
    List<AllDocRow<Map<String, dynamic>>> result3 =
        await sqlAdapter.view("name_view", "name_index");
    print(result3.length);
    expect(result3.length, greaterThan(0));
    List<AllDocRow<Map<String, dynamic>>> result = await sqlAdapter.view(
        "name_view", "name_index",
        startKey: "_a_99",
        endKey: "_a_99\uffff",
        startKeyDocId: "1",
        endKeyDocId: "1\uffff");

    await sqlAdapter.put(doc: Doc(id: "c", model: {"name": "c", "no": 55}));

    List<AllDocRow<Map<String, dynamic>>> result2 = await sqlAdapter.view(
        "name_view", "name_index",
        startKey: "_a_99",
        endKey: "_a_99\uffff",
        startKeyDocId: "1",
        endKeyDocId: "1\uffff");

    expect(result.length, equals(11));
    expect(result2.length, equals(11));
  });

  group('bulkdocs()', () {
    test('create/update/delete new doc with newEdits =true', () async {
      final sqlDb = await getDb();
      final db = KeyValueAdapter(dbName: dbName, db: sqlDb);

      await db.put(
          doc: Doc(id: "2", model: {"name": "2"}, rev: Rev.fromString("2-a")),
          newEdits: false);
      await db.put(
          doc: Doc(id: "4", model: {"name": "4"}, rev: Rev.fromString("4-a")),
          newEdits: false);

      BulkDocResponse bulkDocResponse = await db.bulkDocs(body: [
        Doc(id: "1", model: {"name": "1"}),
        Doc(id: "2", rev: Rev.fromString("2-a"), model: {"name": "2"}),
        Doc(id: "3", model: {"name": "3"}),
        Doc(id: "4", model: {}, rev: Rev.fromString("4-a"), deleted: true)
      ], newEdits: true);

      expect(bulkDocResponse.putResponses.length, 4);
      expect(bulkDocResponse.putResponses[0].ok, true);
      expect(bulkDocResponse.putResponses[1].ok, true);
      expect(bulkDocResponse.putResponses[2].ok, true);
      expect(bulkDocResponse.putResponses[3].ok, true);

      Doc<Map<String, dynamic>>? doc = await db.get<Map<String, dynamic>>(
          id: "4", fromJsonT: (value) => value);
      //winner doc is null
      expect(doc, isNull);
    });

    test('create/update/delete new doc with newEdits =false', () async {
      final sqlDb = await getDb();
      final db = KeyValueAdapter(dbName: dbName, db: sqlDb);

      await db.put(
          doc: Doc(id: "2", model: {"name": "2"}, rev: Rev.fromString("2-a")),
          newEdits: false);
      await db.put(
          doc: Doc(id: "4", model: {"name": "4"}, rev: Rev.fromString("4-a")),
          newEdits: false);
      BulkDocResponse bulkDocResponse = await db.bulkDocs(body: [
        Doc(id: "1", rev: Rev.fromString("1-a"), model: {"name": "1"}),
        Doc(
            id: "2",
            rev: Rev.fromString("2-aa"),
            model: {"name": "2"},
            revisions: Revisions(ids: ["aa", "a"], start: 2)),
        Doc(
          id: "3",
          rev: Rev.fromString("3-a"),
          model: {"name": "3"},
        ),
        Doc(
            id: "4",
            model: {},
            rev: Rev.fromString("5-a"),
            deleted: true,
            revisions: Revisions(ids: ["a", "a"], start: 5))
      ], newEdits: false);

      expect(bulkDocResponse.putResponses.length, 4);
      expect(bulkDocResponse.putResponses[0].ok, true);
      expect(bulkDocResponse.putResponses[1].ok, true);
      expect(bulkDocResponse.putResponses[2].ok, true);
      expect(bulkDocResponse.putResponses[3].ok, true);

      Doc<Map<String, dynamic>>? doc = await db.get<Map<String, dynamic>>(
          id: "4", fromJsonT: (value) => value);
      //winner doc is null
      expect(doc, isNull);
    });
  });

  group('put()', () {
    test('create with newEdits =true', () async {
      final sqlDb = await getDb();
      final sqlAdapter = KeyValueAdapter(dbName: dbName, db: sqlDb);

      await sqlAdapter.put(doc: Doc(id: "1", model: {"name": "abc"}));

      var doc = await sqlAdapter.get<Map<String, dynamic>>(
          id: "1", fromJsonT: (value) => value);
      expect(doc, isNotNull);
    });
    test('update with newEdits =true', () async {
      final sqlDb = await getDb();
      final sqlAdapter = KeyValueAdapter(dbName: dbName, db: sqlDb);

      await sqlAdapter.put(
          doc: Doc(id: "1", model: {"name": "abc"}, rev: Rev.fromString("1-a")),
          newEdits: false);

      var doc = await sqlAdapter.get<Map<String, dynamic>>(
          id: "1", fromJsonT: (value) => value);
      expect(doc, isNotNull);
      expect(doc?.rev?.toString(), "1-a");

      await sqlAdapter.put(
          doc:
              Doc(id: "1", rev: Rev.fromString("1-a"), model: {"name": "abc"}));

      var doc2 = await sqlAdapter.get<Map<String, dynamic>>(
          id: "1", fromJsonT: (value) => value);
      expect(doc2, isNotNull);
      expect(doc2?.rev?.index, 2);
    });

    test('create with newEdits =false', () async {
      final sqlDb = await getDb();
      final sqlAdapter = KeyValueAdapter(dbName: dbName, db: sqlDb);

      await sqlAdapter.put(
          doc: Doc(id: "1", rev: Rev.fromString("1-a"), model: {"name": "abc"}),
          newEdits: false);
      var doc = await sqlAdapter.get<Map<String, dynamic>>(
          id: "1", fromJsonT: (value) => value);
      expect(doc, isNotNull);
    });
    test('update with newEdits =false', () async {
      final sqlDb = await getDb();
      final sqlAdapter = KeyValueAdapter(dbName: dbName, db: sqlDb);

      await sqlAdapter.put(
          doc: Doc(id: "1", rev: Rev.fromString("1-a"), model: {"name": "abc"}),
          newEdits: false);
      var doc = await sqlAdapter.get<Map<String, dynamic>>(
          id: "1", fromJsonT: (value) => value);
      expect(doc, isNotNull);

      await sqlAdapter.put(
          doc: Doc(
              id: "1",
              rev: Rev.fromString("2-a"),
              model: {"name": "abc"},
              revisions: Revisions(ids: ['a', 'a'], start: 2)),
          newEdits: false);
      var doc2 = await sqlAdapter.get<Map<String, dynamic>>(
          id: "1", fromJsonT: (value) => value);
      expect(doc2, isNotNull);
      expect(doc2?.rev.toString(), "2-a");
    });
  });

  test("delete()", () async {
    final sqlDb = await getDb();
    final sqlAdapter = KeyValueAdapter(dbName: dbName, db: sqlDb);
    await sqlAdapter.put(
        doc: Doc(id: "1", model: {}, rev: Rev.fromString("1-a")),
        newEdits: false);
    await sqlAdapter.delete(id: "1", rev: Rev.fromString("1-a"));
    var doc = await sqlAdapter.get<Map<String, dynamic>>(
        id: "1", fromJsonT: (value) => value);
    expect(doc, isNull);
  });
}
