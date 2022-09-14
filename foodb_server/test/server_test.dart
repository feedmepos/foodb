@Timeout(Duration(seconds: 1000))
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_server/abstract_foodb_server.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb_server/types.dart';
import 'package:test/test.dart';

import 'ssl/ssl_certs.dart';

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

void main() {
  test('url', () async {
    final url = Uri.parse('http://127.0.0.1/db_id/doc_id?test=1');
    url.queryParameters['test'];
    url.pathSegments;
  });

  test('get', () async {
    Foodb db = Foodb.couchdb(
        dbName: 'restaurant_61a9935e94eb2c001d618bc3',
        baseUri: Uri.parse('http://admin:ieXZW5@localhost:6984'));
    final server = WebSocketFoodbServer(
      db: db,
      config: FoodbServerConfig(username: 'admin', password: 'secret'),
    );
    await server.start(port: 6987);
    final doc = await server
        .handleRequest(FoodbServerRequest.fromWebSocketMessage(jsonEncode({
      'method': 'GET',
      'url':
          'http://admin:secret@127.0.0.1:6987/restaurant_61a9935e94eb2c001d618bc3/bill_2022-03-17T10:37:41.941Z_b74d',
      'messageId': ''
    })));
    print(doc);
  });

  testFn(Future<void> Function(Foodb) fn) async {
    load('.env');
    final httpServerPortNo =
        int.parse(env['DEV_HTTP_SERVER_PORT_NO'] ?? '6987');
    final websocketServerPortNo =
        int.parse(env['DEV_WEBSOCKET_SERVER_PORT_NO'] ?? '6988');

    var types = [
      {
        'client': (String dbName) => Foodb.couchdb(
              dbName: dbName,
              baseUri: Uri.parse(
                  'https://admin:machineId@127.0.0.1:$httpServerPortNo'),
            ),
        'server': (Foodb db) => HttpFoodbServer(
              db: db,
              config: FoodbServerConfig(
                  username: 'admin',
                  password: 'machineId',
                  securityContext: getSecurityContext()),
            ),
        'port': httpServerPortNo,
      },
      {
        'client': (String dbName) => Foodb.websocket(
              dbName: dbName,
              baseUri: Uri.parse(
                  'wss://admin:machineId@127.0.0.1:$websocketServerPortNo'),
            ),
        'server': (db) => WebSocketFoodbServer(
              db: db,
              config: FoodbServerConfig(
                  username: 'admin',
                  password: 'machineId',
                  securityContext: getSecurityContext()),
            ),
        'port': websocketServerPortNo,
      },
    ];

    final dbName = 'restaurant_61a9935e94eb2c001d618bc3';
    final localCouchDbPassword = env['DEV_LOCAL_COUCH_DB_PASSWORD'] ??
        'Enter Your Local Couch DB Password';

    Foodb db = Foodb.couchdb(
        dbName: dbName,
        baseUri: Uri.parse(
          'http://admin:${localCouchDbPassword}@localhost:6984',
        ));

    for (final type in types) {
      final server = (type['server'] as dynamic)(db);

      await server.start(port: type['port']);

      final client = (type['client'] as dynamic)(dbName);

      await fn(client);
    }
  }

  test('client with http server get', () async {
    HttpOverrides.global = HttpTrustSelfSignOverride();
    await testFn((client) async {
      final docId = 'bill_2022-03-17T10:37:41.941Z_b74d';
      print((await client.get(id: docId, fromJsonT: (v) => v))
          ?.toJson((value) => value));
      print((await client.serverInfo()).toJson());
    });
  });

  test('client with http server changes normal', () async {
    HttpOverrides.global = HttpTrustSelfSignOverride();
    await testFn((client) async {
      final completer = Completer();
      client.changesStream(
        ChangeRequest(
            feed: ChangeFeed.normal,
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

  test('client with http server changes long poll', () async {
    await testFn((client) async {
      final completer = Completer();
      client.changesStream(
        ChangeRequest(
            feed: ChangeFeed.longpoll,
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

  test('client with http server changes continuous', () async {
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
            method: 'GET', uri: Uri.parse('http://localhost:3000/_revs_diff')),
      ),
      false,
    );
  });
}
