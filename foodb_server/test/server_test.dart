@Timeout(Duration(seconds: 1000))
import 'dart:convert';
import 'package:foodb/foodb.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb_server/http_server.dart';
import 'package:foodb_server/websocket_server.dart';
import 'package:test/test.dart';

void main() {
  test('url', () async {
    final url = Uri.parse('http://127.0.0.1/db_id/doc_id?test=1');
    url.queryParameters['test'];
    url.pathSegments;
  });

  test('get', () async {
    Foodb db = Foodb.couchdb(
        dbName: 'restaurant_61a9935e94eb2c001d618bc3',
        baseUri: Uri.parse('https://admin:secret@sync-dev.feedmeapi.com'));
    final server = WebSocketFoodbServer(db);
    await server.start();
    final doc = await server
        .handleRequest(FoodbRequest.fromWebSocketMessage(jsonEncode({
      'method': 'GET',
      'url':
          'http://127.0.0.1/restaurant_61a9935e94eb2c001d618bc3/bill_2021-12-03T03:48:51.965Z_2emf',
      'messageId': ''
    })));
    print(doc);
  });

  test('client with websocket server get', () async {
    final dbName = 'restaurant_61a9935e94eb2c001d618bc3';
    final docId = 'bill_2021-12-03T03:48:51.965Z_2emf';
    Foodb db = Foodb.couchdb(
        dbName: dbName,
        baseUri: Uri.parse('https://admin:secret@sync-dev.feedmeapi.com'));
    final server = WebSocketFoodbServer(db);
    await server.start(port: 6987);

    Foodb websocketClient = Foodb.websocket(
      dbName: dbName,
      baseUri: Uri.parse('ws://127.0.0.1:6987'),
    );
    final result = await websocketClient.get(id: docId, fromJsonT: (v) => v);
    print(result?.toJson((value) => value));
  });

  test('client with http server get', () async {
    final dbName = 'restaurant_61a9935e94eb2c001d618bc3';
    final docId = 'bill_2021-12-03T03:48:51.965Z_2emf';

    Foodb db = Foodb.couchdb(
        dbName: dbName,
        baseUri: Uri.parse('https://admin:secret@sync-dev.feedmeapi.com'));
    final httpServer = HttpFoodbServer(db);

    await httpServer.start(port: 6987);

    final httpClient = Foodb.couchdb(
      dbName: dbName,
      baseUri: Uri.parse('http://127.0.0.1:6987'),
    );

    final result = await httpClient.get(id: docId, fromJsonT: (v) => v);
    print(result?.toJson((value) => value));
  });

  test('test route match', () {
    final path = '/<db>/_revs_diff';
    expect(
      RouteMatcher.get(
        path: path,
        request: FoodbRequest(
            method: 'GET',
            uri: Uri.parse('http://localhost:3000/restaurant_1/_revs_diff')),
      ),
      true,
    );
    expect(
      RouteMatcher.get(
        path: path,
        request: FoodbRequest(
            method: 'POST',
            uri: Uri.parse('http://localhost:3000/restaurant_1/_revs_diff')),
      ),
      false,
    );
    expect(
      RouteMatcher.get(
        path: path,
        request: FoodbRequest(
            method: 'GET', uri: Uri.parse('http://localhost:3000/_revs_diff')),
      ),
      false,
    );
  });
}
