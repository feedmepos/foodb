import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:foodb_server/types.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:foodb_server/abstract_foodb_server.dart';
import 'package:foodb/foodb.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketFoodbServer extends FoodbServer {
  WebSocketFoodbServer({
    required Future<Foodb> Function(String dbName) dbFactory,
    FoodbServerConfig? config,
  }) : super(dbFactory: dbFactory, config: config);
  HttpServer? _server;

  @override
  Future<void> start({int? port}) async {
    int serverPort = getServerPort(port: port);

    await super.init();
    final handler = webSocketHandler((WebSocketChannel websocket) {
      websocket.stream.listen((message) async {
        final request = FoodbServerRequest.fromWebSocketMessage(message);
        final response = await handleRequest(request);
        final responseData = response.data;
        if (responseData is Stream<List<int>>) {
          responseData.listen((event) {
            final data = jsonDecode(utf8.decode(event));
            websocket.sink.add(jsonEncode({
              'data': data,
              'requestId': request.id,
              'hold': request.hold,
              'status': response.status ?? 200,
            }));
          });
        } else {
          websocket.sink.add(jsonEncode({
            'data': (responseData ?? {}),
            'requestId': request.id,
            'hold': request.hold,
            'status': response.status ?? 200
          }));
        }
      });
    });

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      serverPort,
      securityContext: config?.securityContext,
    );
    print('Serving at ws://${_server?.address.host}:$serverPort');
  }

  @override
  Future<void> stop() async {
    await _server?.close();
  }
}
