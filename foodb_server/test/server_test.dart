import 'dart:io';

import 'package:foodb/foodb.dart';
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb_server/websocket_server.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  // final port = '8080';
  // final host = 'http://0.0.0.0:$port';
  // late Process p;

  // setUp(() async {
  //   p = await Process.start(
  //     'dart',
  //     ['run', 'bin/server.dart'],
  //     environment: {'PORT': port},
  //   );
  //   // Wait for server to start and print to stdout.
  //   await p.stdout.first;
  // });

  // tearDown(() => p.kill());

  // test('Root', () async {
  //   final response = await get(Uri.parse('$host/'));
  //   expect(response.statusCode, 200);
  //   expect(response.body, 'Hello, World!\n');
  // });

  // test('Echo', () async {
  //   final response = await get(Uri.parse('$host/echo/hello'));
  //   expect(response.statusCode, 200);
  //   expect(response.body, 'hello\n');
  // });

  // test('404', () async {
  //   final response = await get(Uri.parse('$host/foobar'));
  //   expect(response.statusCode, 404);
  // });
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
    final doc = await server.handleRequest(FoodbRequest.fromWebSocketMessage({
      'method': 'GET',
      'url':
          'http://127.0.0.1/restaurant_61a9935e94eb2c001d618bc3/bill_2021-12-03T03:48:51.965Z_2emf',
    }));
    print(doc);
    // restaurant_61a9935e94eb2c001d618bc3
    // bill_2021-12-03T03:48:51.965Z_2emf
    // GET http://127.0.0.1:6984/db_name/id
    // Foodb websocketClient = Foodb.websocket(dbName: '', baseUri: Uri());
    // final result = await websocketClient.get(id: '', fromJsonT: (v) => v);
  });
}
