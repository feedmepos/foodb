@Timeout(Duration(seconds: 1000))
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:test/test.dart';
import 'ssl/ssl_certs.dart';

List<Doc<Map<String, dynamic>>> mockDocs = [
  Doc(id: '1', model: {}),
];

class HttpTrustSelfSignOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = Duration(milliseconds: 3000)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

SecurityContext getSecurityContext() {
  final certChainBytes = getCertChainBytes();
  final certKeyBytes = getCertKeyBytes();

  return SecurityContext()
    ..setTrustedCertificatesBytes(certChainBytes)
    ..useCertificateChainBytes(certChainBytes)
    ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');
}

testFn(Future<void> Function(Foodb) fn) async {
  final httpServerPortNo = int.parse(env['DEV_HTTP_SERVER_PORT_NO'] ?? '6987');
  final websocketServerPortNo =
      int.parse(env['DEV_WEBSOCKET_SERVER_PORT_NO'] ?? '6988');

  var types = [
    {
      'client': (String dbName) => Foodb.couchdb(
            dbName: dbName,
            baseUri: Uri.parse(
                'https://admin:machineId@127.0.0.1:$httpServerPortNo'),
          ),
      'server': (
        Future<Foodb> Function(String) dbFactory,
        FoodbServerConfig config,
      ) =>
          HttpFoodbServer(
            dbFactory: dbFactory,
            config: config,
          ),
      'port': httpServerPortNo,
    },
    {
      'client': (String dbName) => Foodb.websocket(
            dbName: dbName,
            baseUri: Uri.parse(
                'wss://admin:machineId@127.0.0.1:$websocketServerPortNo'),
          ),
      'server': (
        Future<Foodb> Function(String) dbFactory,
        FoodbServerConfig config,
      ) =>
          WebSocketFoodbServer(
            dbFactory: dbFactory,
            config: config,
          ),
      'port': websocketServerPortNo,
    },
  ];

  final dbName = 'restaurant_61a9935e94eb2c001d618bc3';
  final localCouchDbPassword = env['DEV_LOCAL_COUCH_DB_PASSWORD'] ??
      'Enter Your Local Couch DB Password';

  for (final type in types) {
    final server = (type['server'] as dynamic)(
      (dbName) async {
        final db = Foodb.keyvalue(
          dbName: dbName,
          keyValueDb: KeyValueAdapter.inMemory(),
        );
        await db.bulkDocs(body: mockDocs);
        return db;
        // return Foodb.couchdb(
        //   dbName: dbName,
        //   baseUri: Uri.parse(
        //     'http://admin:${localCouchDbPassword}@localhost:6984',
        //   ),
        // );
      },
      FoodbServerConfig(
        auths: [
          DatabaseAuth(
            database: dbName,
            username: 'admin',
            password: 'machineId',
          )
        ],
        securityContext: getSecurityContext(),
      ),
    );

    await server.start(port: type['port']);

    final client = (type['client'] as dynamic)(dbName);

    await fn(client);
  }
}

void main() {
  load('.env');

  group('utility test |', () {
    test('url', () async {
      final url = Uri.parse('http://127.0.0.1/db_id/doc_id?test=1');
      url.queryParameters['test'];
      url.pathSegments;
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

  group('websocket reconnect |', () {
    final localDbName =
        env['DEV_LOCAL_COUCH_DB_NAME'] ?? 'Enter Your Local Couch DB Name Here';
    final localCouchDbPassword = env['DEV_LOCAL_COUCH_DB_PASSWORD'] ??
        'Enter Your Local Couch DB Password Here';
    final localDbPort = 6984;
    final fooDbUsername = 'admin';
    final fooDbPassword = 'machineId';
    final fooDbPort = 6987;
    final availableDocId = '1';
    final unavailableDocId = 'qwerty';
    final timeoutSeconds = 30;

    Future<Foodb> dbFactory(dbName) async {
      final db = Foodb.keyvalue(
        dbName: dbName,
        keyValueDb: KeyValueAdapter.inMemory(),
      );
      await db.put(doc: Doc(id: availableDocId, model: {}));
      return db;
    }

    final server = WebSocketFoodbServer(
        dbFactory: dbFactory,
        config: FoodbServerConfig(
          auths: [
            DatabaseAuth(
              database: localDbName,
              username: 'admin',
              password: 'machineId',
            )
          ],
        ));

    test(
        'start server > start client > client connects server with available doc',
        () async {
      await server.start(port: fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort.toString()}'),
          timeoutSeconds: timeoutSeconds);

      final res = await client.get(id: availableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      await server.stop();
    });

    test(
        'start server > start client > client connects server with unavailable doc',
        () async {
      await server.start(port: fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort}'),
          timeoutSeconds: timeoutSeconds);

      final res = await client.get(id: unavailableDocId, fromJsonT: (v) => v);
      expect(res, isNull);
      await server.stop();
    });

    test(
        'no server started >  start client > client connects server with available doc > timeout exception',
        () async {
      print('no server started');

      final client = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort}'),
          timeoutSeconds: timeoutSeconds);

      expect(() async {
        await client.get(id: availableDocId, fromJsonT: (v) => v);
      }, throwsException);

      await server.stop();
    });

    test(
        'TODO: start server > start client > client connects server > stop server > client reconnects > should get nothing',
        () async {
      await server.start(port: fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort.toString()}'),
          timeoutSeconds: timeoutSeconds);

      final res = await client.get(id: availableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      await server.stop();
      print('server stopped');

      final res2 = await client.get(id: availableDocId, fromJsonT: (v) => v);

      // TODO: should get null
      // expect(res2, isNull);
      await server.stop();
    });

    test(
        'start server > start client > client connects server > stop server > new client connect > timeout exception',
        () async {
      await server.start(port: fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort.toString()}'),
          timeoutSeconds: timeoutSeconds);

      final res = await client.get(id: availableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      await server.stop();
      print('server stopped');

      print('connect with new client');
      final newClient = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort.toString()}'),
          timeoutSeconds: 30);

      expect(() async {
        await newClient.get(id: availableDocId, fromJsonT: (v) => v);
      }, throwsException);
      await server.stop();
    });

    test(
        'start server > start client > client connects server > stop server > restart server after 10s > old and new client connect',
        () async {
      await server.stop();
      await server.start(port: fooDbPort);
      print('server started');

      final client = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort.toString()}'),
          timeoutSeconds: timeoutSeconds);

      final res = await client.get(id: availableDocId, fromJsonT: (v) => v);
      expect(res, isNotNull);
      server.stop();
      print('server stopped');

      await Future.delayed(Duration(seconds: 10));
      server.start(port: fooDbPort);
      print('server restarted');

      print('connect with old client');
      final res2 = await client.get(id: availableDocId, fromJsonT: (v) => v);
      expect(res2, isNotNull);

      print('connect with new client');
      final newClient = Foodb.websocket(
          dbName: localDbName,
          baseUri: Uri.parse(
              'ws://$fooDbUsername:$fooDbPassword@127.0.0.1:${fooDbPort.toString()}'),
          timeoutSeconds: timeoutSeconds);
      final res3 = await newClient.get(id: availableDocId, fromJsonT: (v) => v);
      expect(res3, isNotNull);
    });
  });

  group('change stream | client with http server changes | ', () {
    HttpOverrides.global = HttpTrustSelfSignOverride();
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
        final completer = Completer();
        client.changesStream(
          ChangeRequest(
              feed: ChangeFeed.continuous,
              since:
                  '6782-g1AAAACueJzLYWBgYMxgTmGwT84vTc5ISXKA0row2lAPTUQvJbVMr7gsWS85p7S4JLVILyc_OTEnB2gQUyJDHgvDfyDIymBOYmCQqssFirKbpKYkWiaZUG5HFgCzvDuS'),
          onComplete: (response) {
            print('onComplete ${response.toJson()}');
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
  });

  group('general test |', () {
    test('get', () async {
      final dbId = 'restaurant_61a9935e94eb2c001d618bc3';
      List<Doc<Map<String, dynamic>>> mockDocs = [
        Doc(id: '1', model: {}),
      ];
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
          DatabaseAuth(database: dbId, username: 'admin', password: 'secret')
        ]),
      );
      await server.start(port: 6987);
      final response = await server
          .handleRequest(FoodbServerRequest.fromWebSocketMessage(jsonEncode({
        'method': 'GET',
        'url': 'http://admin:secret@127.0.0.1:6987/$dbId/1',
        'messageId': ''
      })));
      expect(response.data['_id'], mockDocs[0].id);
    });
  });
}
