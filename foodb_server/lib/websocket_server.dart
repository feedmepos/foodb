import 'dart:convert';
import 'dart:io';

import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb/foodb.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketFoodbServer extends FoodbServer {
  WebSocketFoodbServer(Foodb db) : super(db);

  @override
  Future<void> start({int port = 6984}) async {
    final handler = webSocketHandler((WebSocketChannel websocket) {
      websocket.stream.listen((message) async {
        print("echo $message");
        final request = FoodbRequest.fromWebSocketMessage(message);
        final result = await handleRequest(request);
        websocket.sink.add(jsonEncode({
          ...(result ?? {}),
          'messageId': request.messageId,
        }));
      });
    });

    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    initRoutes();
    print('Serving at ws://${server.address.host}:${server.port}');
  }
}
