import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SqliteProvider {
  String dbName;
  Database? _database;

  SqliteProvider({required this.dbName, Database? database}) {
    this._database = database;
  }

  Future<Database> get database async {
    if (_database == null) _database = await createDatabase();
    return _database!;
  }

  Future<void> removeDatabase() async {
    await deleteDatabase(join(await getDatabasesPath(), "$dbName.db"));
  }

  Future<Database> createDatabase() async {
    var database = await openDatabase(
        join(await getDatabasesPath(), "$dbName.db"),
        version: 1,
        onCreate: initDB,
        onUpgrade: onUpgrade);
    return database;
  }

  //This is optional, and only used for changing DB schema migrations
  void onUpgrade(Database database, int oldVersion, int newVersion) async {
    if (newVersion > oldVersion) {}
  }

  void initDB(Database database, int version) async {
    await database.execute("CREATE TABLE foodb_${dbName}_docs ("
        "key TEXT PRIMARY KEY, "
        "value TEXT "
        ")");
    await database.execute("CREATE TABLE foodb_${dbName}_sequences ("
        "key NUMBER PRIMARY KEY, "
        "value TEXT "
        ")");
    await database.execute("CREATE TABLE foodb_${dbName}_ ("
        "key TEXT PRIMARY KEY, "
        "value TEXT "
        ")");
    await database.execute("CREATE TABLE foodb_${dbName}_viewmeta ("
        "key TEXT PRIMARY KEY, "
        "value TEXT "
        ")");
  }
}
