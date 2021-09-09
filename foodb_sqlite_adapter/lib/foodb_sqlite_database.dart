import 'dart:convert';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb_sqlite_adapter/sqlite_provider.dart';
import 'package:sqflite/sqflite.dart';

class SqliteDatabaseSession extends KeyValueDatabaseSession {
  @override
  var batch;

  SqliteDatabaseSession({required Batch batch}) {
    this.batch = batch;
  }
}

class SqliteDatabase implements KeyValueDatabase {
  late var factory;
  late SqliteProvider dbProvider;
  SqliteDatabase({Database? database, required String dbName}) {
    this.dbProvider = SqliteProvider(dbName: dbName, database: database);
  }

  @override
  Future<List<Object?>> runInSession(
      Function(KeyValueDatabaseSession session) runSession) async {
    final db = await dbProvider.database;
    final batch = await db.batch();
    await runSession(SqliteDatabaseSession(batch: batch));
    return await batch.commit();
  }

  @override
  Future<bool> delete(String tableName,
      {required key, KeyValueDatabaseSession? session}) async {
    final db = await dbProvider.database;
    session == null
        ? (await db.delete(tableName, where: 'key = ?', whereArgs: [key]))
        : session.batch.delete(tableName, where: 'key = ?', whereArgs: [key]);

    return true;
  }

  @override
  Future<Map<String, dynamic>?> get(String tableName, {required key}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);
    List<Map<String, dynamic>> result = [];
    result = await db.query(tableName, where: 'key = ?', whereArgs: [key]);
    List<Map<String, dynamic>> docs = result
        .map((e) => jsonDecode(e["value"]) as Map<String, dynamic>)
        .toList();
    return docs.length == 0 ? null : docs[0];
  }

  @override
  Future<MapEntry<String, dynamic>?> last(String tableName) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);
    var result =
        List.from(await db.query(tableName, orderBy: "key DESC", limit: 1));
    List<MapEntry<String, dynamic>> list = result.isNotEmpty
        ? result
            .map<MapEntry<String, dynamic>>(
                (item) => MapEntry(item["key"], jsonDecode(item["value"])))
            .toList()
        : [];

    return list.length > 0 ? list[0] : null;
  }

  @override
  Future<MapEntry<int, dynamic>?> lastSequence(String tableName) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);

    var result =
        List.from(await db.query(tableName, orderBy: "key DESC", limit: 1));
    List<MapEntry<int, dynamic>> list = result.isNotEmpty
        ? result
            .map<MapEntry<int, dynamic>>(
                (item) => MapEntry(item["key"], jsonDecode(item["value"])))
            .toList()
        : [];

    return list.length > 0 ? list[0] : null;
  }

  @override
  Future<bool> put(String tableName,
      {required key,
      required Map<String, dynamic> object,
      KeyValueDatabaseSession? session}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);

    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    Map<String, dynamic>? doc = await get(tableName, key: key);
    stopwatch.stop();
    print("#6 get in put ${stopwatch.elapsedMilliseconds}");
    if (doc == null) {
      Stopwatch stopwatch2 = new Stopwatch();
      stopwatch2.start();
      session == null
          ? (await db
              .insert(tableName, {"key": key, "value": jsonEncode(object)}))
          : session.batch
              .insert(tableName, {"key": key, "value": jsonEncode(object)});
      stopwatch2.stop();
      print("#7 put in put ${stopwatch2.elapsedMilliseconds}");
    } else {
      Stopwatch stopwatch3 = new Stopwatch();
      stopwatch3.start();
      // await db.rawUpdate('UPDATE $tableName SET value =? WHERE key =?',
      //     [jsonEncode(object), id]);
      session == null
          ? (await db.update(tableName, {"value": jsonEncode(object)},
              where: "key = ?", whereArgs: [key]))
          : session.batch.update(tableName, {"value": jsonEncode(object)},
              where: "key = ?", whereArgs: [key]);
      stopwatch3.stop();
      print("#8 update in put ${stopwatch3.elapsedMilliseconds}");
    }
    return true;
  }

  @override
  Future<ReadResult> read(String tableName,
      {String? startkey, String? endkey, bool? desc}) async {
    final db = await dbProvider.database;
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    createTableIfNotExist(tableName, db);
    stopwatch.stop();
    print("#1 createTableIfNotExist ${stopwatch.elapsedMilliseconds}");
    List<Map<String, dynamic>> result = [];

    if (startkey != null || endkey != null) {
      result = await db.query(tableName,
          orderBy: "key ${desc == true ? "DESC" : "ASC"}",
          where: 'key BETWEEN "${startkey ?? ""}" AND "${endkey ?? "\uffff"}"');
    } else {
      result = await db.query(
        tableName,
        orderBy: "key ${desc == true ? "DESC" : "ASC"}",
      );
    }

    Map<String, dynamic> docs = Map.fromIterable(result,
        key: (e) => e["key"], value: (e) => jsonDecode(e["value"]));
    print("docs.length ${docs.length}");
    return ReadResult(
        docs: docs, offset: 0, totalRows: await tableSize(tableName));
  }

  @override
  Future<int> tableSize(String tableName) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);

    int count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableName')) ??
        0;
    return count;
  }

  Future<void> createTableIfNotExist(String tableName, Database db) async {
    await db.execute(
        "CREATE TABLE IF NOT EXISTS $tableName (key TEXT PRIMARY KEY, value TEXT )");
  }

  @override
  Future<Map<int, dynamic>> readSequence(String tableName,
      {int? startkey, int? endkey, bool? desc}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);
    List<Map<String, dynamic>> result = [];

    if (startkey != null || endkey != null) {
      result = await db.query(tableName,
          orderBy: "key ${desc == true ? "DESC" : "ASC"}",
          where: 'key BETWEEN "${startkey ?? ""}" AND "${endkey ?? "\uffff"}"');
    } else {
      result = await db.query(
        tableName,
        orderBy: "key ${desc == true ? "DESC" : "ASC"}",
      );
    }

    Map<int, dynamic> docs = Map.fromIterable(result,
        key: (e) => e["key"], value: (e) => jsonDecode(e["value"]));

    return docs;
  }

  @override
  Future<void> batchInsert(String tableName,
      {required key,
      required Map<String, dynamic> object,
      required KeyValueDatabaseSession session}) async {
    final db = await dbProvider.database;

    await createTableIfNotExist(tableName, db);

    session.batch.insert(tableName, {"key": key, "value": jsonEncode(object)});
  }

  @override
  Future<void> batchUpdate(String tableName,
      {key,
      required Map<String, dynamic> object,
      required KeyValueDatabaseSession session}) async {
    final db = await dbProvider.database;

    await createTableIfNotExist(tableName, db);

    session.batch.update(tableName, {"value": jsonEncode(object)},
        where: "key = ?", whereArgs: [key]);
  }
}
