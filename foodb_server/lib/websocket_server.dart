part of './abstract_foodb_server.dart';

class WebSocketFoodbServer extends FoodbServer {
  WebSocketFoodbServer({
    required Future<Foodb> Function(String dbName) dbFactory,
    FoodbServerConfig? config,
  }) : super(dbFactory: dbFactory, config: config);
  HttpServer? _server;
  List<WebSocketChannel> websockets = [];

  @override
  Future<void> start({int? port}) async {
    int serverPort = getServerPort(port: port);

    await super.init();
    final handler = webSocketHandler((WebSocketChannel websocket) {
      StreamSubscription<List<int>>? continuousStream;
      websockets.add(websocket);
      websocket.stream.listen((message) async {
        final request = FoodbServerRequest.fromWebSocketMessage(message);
        final response = await handleRequest(request);
        final responseData = response.data;
        if (responseData is StreamController<List<int>>) {
          continuousStream = responseData.stream.listen(null);
          continuousStream!.onData((event) {
            final dataStr = utf8.decode(event);
            websocket.sink.add(jsonEncode({
              'data': dataStr == '\n' ? dataStr : jsonDecode(dataStr),
              'requestId': request.id,
              'hold': request.hold,
              'status': response.status ?? 200,
            }));
          });
          continuousStream!.onError((e, s) {
            print('webssocket route stream error: $e $s');
          });
        } else {
          websocket.sink.add(jsonEncode({
            'data': (responseData ?? {}),
            'requestId': request.id,
            'hold': request.hold,
            'status': response.status ?? 200
          }));
        }
      }, onDone: () {
        continuousStream?.cancel();
        print('websocket connection on done');
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
    for (var websocket in websockets) {
      await websocket.sink.close();
    }
    await _server?.close();
  }
}
