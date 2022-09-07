import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:foodb_server/foodb_server.dart';
import 'package:foodb/foodb.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketFoodbServer extends FoodbServer {
  WebSocketFoodbServer(Foodb db) : super(db) {
    final handler = webSocketHandler((WebSocketChannel websocket) {
      websocket.stream.listen((message) async {
        print("echo $message");
        final result =
            await handleRequest(FoodbRequest.fromWebSocketMessage(message));
        websocket.sink
            .add({...(result ?? {}), 'messageId': message['messageId']});
      });
    });

    shelf_io.serve(handler, 'localhost', 6984).then((server) {
      print('Serving at ws://${server.address.host}:${server.port}');
    });
  }
}
