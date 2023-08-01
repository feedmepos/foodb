import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';

class HttpServerCouchdbTestContext extends FoodbTestContext {
  FoodbServer? server;
  Future<void> _setServer({
    required String prefix,
    required bool autoCompaction,
  }) async {
    server = FoodbServer.http(
      dbFactory: (dbName) async {
        final db = Foodb.keyvalue(
          dbName: '$prefix$dbName',
          keyValueDb: KeyValueAdapter.inMemory(),
          autoCompaction: autoCompaction,
        );
        await db.initDb();
        return db;
      },
      config: null,
    );
    await server!.start(port: 6987);
  }

  @override
  Future<Foodb> db(
    String dbName, {
    bool? persist,
    String prefix = 'test-',
    bool autoCompaction = false,
  }) async {
    await server?.stop();
    await _setServer(
      prefix: prefix,
      autoCompaction: autoCompaction,
    );
    var db = Foodb.couchdb(
        dbName: dbName,
        baseUri: Uri.parse(
          'http://127.0.0.1:6987',
        ));
    if (persist == true) {
      try {
        await db.info();
        await db.destroy();
      } catch (err) {
        //
      }
      await db.initDb();
      addTearDown(() async {
        await db.destroy();
        await server?.stop();
      });
    } else {
      await db.initDb();
    }
    return db;
  }
}

class WebSocketServerCouchdbTestContext extends FoodbTestContext {
  FoodbServer? server;
  Future<void> _setServer(
      {required String prefix, required bool autoCompaction}) async {
    server = FoodbServer.websocket(
      dbFactory: (dbName) async {
        final db = Foodb.keyvalue(
          dbName: '$prefix$dbName',
          keyValueDb: KeyValueAdapter.inMemory(),
          autoCompaction: autoCompaction,
        );
        await db.initDb();
        return db;
      },
      config: null,
    );
    await server!.start(port: 6987);
  }

  @override
  Future<Foodb> db(
    String dbName, {
    bool? persist,
    String prefix = 'test-',
    bool autoCompaction = false,
  }) async {
    await server?.stop();
    await _setServer(
      prefix: prefix,
      autoCompaction: autoCompaction,
    );
    var db = Foodb.websocket(
        dbName: dbName,
        baseUri: Uri.parse(
          'ws://127.0.0.1:6987',
        ));
    if (persist == true) {
      try {
        await db.info();
        await db.destroy();
      } catch (err) {
        //
      }
      await db.initDb();
      addTearDown(() async {
        await db.destroy();
        await server?.stop();
      });
    } else {
      await db.initDb();
    }
    return db;
  }
}
