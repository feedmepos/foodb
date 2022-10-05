@Timeout(Duration(seconds: 1000))
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:test/test.dart';
import 'mock_data.dart';
import 'utility.dart';

void main() {
  HttpOverrides.global = HttpTrustSelfSignOverride();

  final ctx = ServerTestContext();

  group('utility test |', () {
    test('parse url', () async {
      final url = Uri.parse('http://127.0.0.1/db_id/doc_id?testA=1&testB=2');
      final queryParamA = url.queryParameters['testA'];
      final queryParamB = url.queryParameters['testB'];
      final pathSegment = url.pathSegments;

      expect(queryParamA, '1');
      expect(queryParamB, '2');
      expect(pathSegment[0], 'db_id');
      expect(pathSegment[1], 'doc_id');
    });
    test('test route match', () {
      final path = '/<db>/_revs_diff';
      expect(
        RouteMatcher.get(
          path: path,
          request: FoodbServerRequest(
              method: 'GET',
              uri: Uri.parse('http://localhost:3000/restaurant_1/_revs_diff')),
        ),
        true,
      );
      expect(
        RouteMatcher.get(
          path: path,
          request: FoodbServerRequest(
              method: 'POST',
              uri: Uri.parse('http://localhost:3000/restaurant_1/_revs_diff')),
        ),
        false,
      );
      expect(
        RouteMatcher.get(
          path: path,
          request: FoodbServerRequest(
              method: 'GET',
              uri: Uri.parse('http://localhost:3000/_revs_diff')),
        ),
        false,
      );
    });
  });
  group('general test |', () {
    test('get', () async {
      Future<Foodb> dbFactory(dbName) async {
        final db = Foodb.keyvalue(
          dbName: dbName,
          keyValueDb: KeyValueAdapter.inMemory(),
        );
        await db.bulkDocs(body: mockDocs);
        return db;
      }

      final server = WebSocketFoodbServer(
        dbFactory: dbFactory,
        config: FoodbServerConfig(auths: [
          DatabaseAuth(
              database: ctx.dbId,
              username: ctx.fooDbUsername,
              password: ctx.fooDbPassword)
        ]),
      );

      await server.start(port: ctx.fooDbPort);

      final responseOne = await server
          .handleRequest(FoodbServerRequest.fromWebSocketMessage(jsonEncode({
        'method': 'GET',
        'url':
            'http://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort}/${ctx.dbId}/${ctx.firstAvailableDocId}',
        'messageId': '',
        'hold': false,
      })));
      expect(responseOne.data['_id'], mockDocs[0].id);
      await server.stop();
    });
  });
  group('websocket reconnect |', () {
    Future<Foodb> dbFactory(dbName) async {
      final db = Foodb.keyvalue(
        dbName: dbName,
        keyValueDb: KeyValueAdapter.inMemory(),
      );
      await db.bulkDocs(body: mockDocs);
      // await db.put(doc: Doc(id: ctx.firstAvailableDocId, model: {}));
      return db;
    }

    final server = WebSocketFoodbServer(
        dbFactory: dbFactory,
        config: FoodbServerConfig(
          auths: [
            DatabaseAuth(
              database: ctx.dbId,
              username: ctx.fooDbUsername,
              password: ctx.fooDbPassword,
            )
          ],
        ));

    test(
        'start server > start client > client connects server with available doc',
        () async {
      await server.start(port: ctx.fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      final res =
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      await server.stop();
    });

    test(
        'start server > start client > client connects server with unavailable doc',
        () async {
      await server.start(port: ctx.fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      final res =
          await client.get(id: ctx.unavailableDocId, fromJsonT: (v) => v);
      expect(res, isNull);
      await server.stop();
    });

    test(
        'no server started >  start client > client connects server with available doc > timeout exception',
        () async {
      print('no server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      expect(() async {
        try {
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
        } catch (e) {
          print(e);
          rethrow;
        }
      }, throwsException);
    });

    test(
        'start server > start client > client connects server > stop server > client reconnects > should get nothing',
        () async {
      await server.start(port: ctx.fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      final res =
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);

      await server.stop();
      print('server stopped');

      expect(() async {
        try {
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
        } catch (e) {
          print(e);
          rethrow;
        }
      }, throwsException);

      await Future.delayed(Duration(seconds: 5));
      await server.start(port: ctx.fooDbPort);
      await Future.delayed(Duration(seconds: 5));

      final res2 = await client.get(id: '2', fromJsonT: (v) => v);
      expect(res2?.id, '2');
      await server.stop();
    });

    test(
        'start server > start client > client starts change stream > stop server > close change stream',
        () async {
      await server.start(port: ctx.fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);
      final completer = Completer();

      client.changesStream(
        ChangeRequest(feed: ChangeFeed.continuous, since: 'now'),
        onComplete: (response) {
          print('onComplete ${response.toJson()}');
        },
        onResult: (response) {
          //
        },
        onError: (error, stacktrace) {
          print('onError $error $stacktrace');
          expect(error, isNotNull);
          completer.complete();
        },
      );

      await Future.delayed(Duration(seconds: 5));
      await server.stop();
      await completer.future;
    });

    test(
        'start server > start client > client connects server > stop server > new client connect > throw disconnect error',
        () async {
      await server.start(port: ctx.fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      final res =
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      await server.stop();
      print('server stopped');

      print('connect with new client');
      final newClient = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      expect(() async {
        try {
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
        } catch (e) {
          print(e);
          rethrow;
        }
      }, throwsException);
      await server.stop();
    });

    test(
        'start server > start client > client connects server > stop server > restart server after 10s > old and new client connect',
        () async {
      await server.stop();
      await server.start(port: ctx.fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);

      final res =
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      server.stop();
      print('server stopped');

      await Future.delayed(Duration(seconds: 10));
      server.start(port: ctx.fooDbPort);
      print('server restarted');

      print('connect with old client');
      final res2 =
          await client.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
      expect(res2, isNotNull);

      print('connect with new client');
      final newClient = Foodb.websocket(
          dbName: ctx.dbId,
          baseUri: Uri.parse(
              'ws://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:${ctx.fooDbPort.toString()}'),
          timeoutSeconds: ctx.timeoutSeconds);
      final res3 =
          await newClient.get(id: ctx.firstAvailableDocId, fromJsonT: (v) => v);
      expect(res3, isNotNull);
      await server.stop();
    });
  });
  group('change stream | client with http server changes | ', () {
    test('normal', () async {
      await testFn((client) async {
        final completer = Completer();
        client.changesStream(
          ChangeRequest(feed: ChangeFeed.normal, since: 'now'),
          onComplete: (response) {
            print('onComplete ${response.toJson()}');
            expect(response.results.length, 0);
            completer.complete();
          },
          onResult: (response) {
            print('onResult ${response.toJson()}');
          },
          onError: (error, stacktrace) {
            print('onComplete $error $stacktrace');
          },
        );
        await completer.future;
      });
    });
    test('long poll', () async {
      await testFn((client) async {
        final completer = Completer();
        final newDocId = DateTime.now().millisecondsSinceEpoch.toString();
        client.changesStream(
          ChangeRequest(feed: ChangeFeed.longpoll, since: 'now'),
          onComplete: (response) {
            print('onComplete ${response.toJson()}');
            expect(response.results.length, 1);
            expect(response.results.first.id, newDocId);
            completer.complete();
          },
          onResult: (response) {
            print('onResult ${response.toJson()}');
            expect(response.id, newDocId);
          },
          onError: (error, stacktrace) {
            print('onError $error $stacktrace');
          },
        );
        await client.put(
          doc: Doc(id: newDocId, model: {}),
        );
        await completer.future;
      });
    });

    test('continuous', () async {
      await testFn((client) async {
        final newDocIdOne = 'doc_1';
        final newDocIdTwo = 'doc_2';

        var resultFn = expectAsync1<void, ChangeResult>((v) {
          print(v.id);
        }, count: 2);

        client.changesStream(
          ChangeRequest(feed: ChangeFeed.continuous, since: 'now'),
          onComplete: (response) {
            print('onComplete ${response.toJson()}');
          },
          onResult: resultFn,
          onError: (error, stacktrace) {
            print('onComplete $error $stacktrace');
          },
        );
        await Future.delayed(Duration(seconds: 2));
        await client.put(
          doc: Doc(id: newDocIdOne, model: {}),
        );
        await Future.delayed(Duration(seconds: 4));
        await client.put(
          doc: Doc(id: newDocIdTwo, model: {}),
        );
      });
    });
  });
}
