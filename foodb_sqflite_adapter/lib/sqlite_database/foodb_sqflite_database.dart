import 'dart:convert';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb_sqflite_adapter/sqlite_database/sqlite_provider.dart';
import 'package:sqflite/sqflite.dart';

class SqliteDatabase implements KeyValueDatabase {
  late var factory;
  late SqliteProvider dbProvider;
  SqliteDatabase({Database? database, required String dbName}) {
    this.dbProvider = SqliteProvider(dbName: dbName, database: database);
  }

  @override
  Future<bool> delete(String tableName, {required String id}) async {
    final db = await dbProvider.database;
    var result = await db.delete(tableName, where: 'key = ?', whereArgs: [id]);

    return true;
  }

  @override
  Future<bool> deleteSequence(String tableName, {required int seq}) async {
    final db = await dbProvider.database;
    var result = await db.delete(tableName, where: 'key = ?', whereArgs: [seq]);

    return true;
  }

  @override
  Future<Map<String, dynamic>?> get(String tableName,
      {required String id}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);
    List<Map<String, dynamic>> result = [];
    result = await db.query(tableName, where: 'key = ?', whereArgs: [id]);
    List<Map<String, dynamic>> docs = result
        .map((e) => jsonDecode(e["value"]) as Map<String, dynamic>)
        .toList();
    return docs.length == 0 ? null : docs[0];
  }

  Future<Map<String, dynamic>?> getSequence(String tableName,
      {required int seq}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);
    List<Map<String, dynamic>> result = [];
    result = await db.query(tableName, where: 'key = ?', whereArgs: [seq]);
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
      {required String id, required Map<String, dynamic> object}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);

    Map<String, dynamic>? doc = await get(tableName, id: id);
    if (doc == null) {
      await db.rawInsert('INSERT INTO $tableName (key, value) '
          'VALUES("$id", \'${jsonEncode(object)}\')');
    } else {
      await db.update(tableName, {"value": jsonEncode(object)},
          where: "key = ?", whereArgs: [id]);
    }
    print(object);
    return true;
  }

  @override
  Future<bool> putSequence(String tableName,
      {required int seq, required Map<String, dynamic> object}) async {
    final db = await dbProvider.database;
    createTableIfNotExist(tableName, db);

    Map<String, dynamic>? doc = await getSequence(tableName, seq: seq);
    if (doc == null) {
      await db.rawInsert('INSERT INTO $tableName (key, value) '
          'VALUES("$seq", \'${jsonEncode(object)}\')');
    } else {
      await db.update(tableName, {"value": jsonEncode(object)},
          where: "key = ?", whereArgs: [seq]);
    }
    print(object);
    return true;
  }

  @override
  Future<ReadResult> read(String tableName,
      {String? startkey, String? endkey, bool? desc}) async {
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

    Map<String, dynamic> docs = Map.fromIterable(result,
        key: (e) => e["key"], value: (e) => jsonDecode(e["value"]));

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
    List<Map<int, dynamic>> result = [];

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

    return docs;
  }
}
