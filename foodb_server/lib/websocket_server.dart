import 'dart:convert';
import 'dart:io';

import 'package:foodb_server/types.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb/foodb.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketFoodbServer extends FoodbServer {
  WebSocketFoodbServer(Foodb db) : super(db);

  @override
  Future<void> start({int port = 6984}) async {
    await super.start();
    final handler = webSocketHandler((WebSocketChannel websocket) {
      websocket.stream.listen((message) async {
        final request = FoodbRequest.fromWebSocketMessage(message);
        var response = await handleRequest(request);
        if (response is Stream<List<int>> && request.type == 'stream') {
          response.listen((event) {
            final data = jsonDecode(utf8.decode(event));
            websocket.sink.add(jsonEncode({
              'data': data,
              'messageId': request.messageId,
              'type': request.type,
              'status': 200,
            }));
          });
        } else if (response is Stream<List<int>>) {
          response.listen((event) {
            final data = jsonDecode(utf8.decode(event));
            websocket.sink.add(jsonEncode({
              'data': data,
              'messageId': request.messageId,
              'type': request.type,
              'status': 200,
            }));
          });
        } else {
          websocket.sink.add(jsonEncode({
            'data': (response ?? {}),
            'messageId': request.messageId,
            'type': request.type,
            'status': 200
          }));
        }
      });
    });

    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('Serving at ws://${server.address.host}:${server.port}');
  }
}
