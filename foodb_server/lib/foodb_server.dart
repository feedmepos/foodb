import 'package:foodb/foodb.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:web_socket_channel/web_socket_channel.dart';

class Request {
  String path;
  Map<String, dynamic> params;
  Map<String, dynamic> body;
  Request({
    required this.path,
    required this.params,
    required this.body,
  });

  static Request fromJson(Map<String, dynamic> json) {
    return Request(path: '', params: {}, body: {});
  }
}

abstract class FoodbServer {
  final Foodb db;
  FoodbServer(this.db);

  Future<dynamic> _get(Request request) async {
    return db.get(id: request.path, fromJsonT: (v) => v);
  }

  Future<Map<String, dynamic>> _handleRequest(Request request) async {
    switch (request.path) {
      case 'get':
        {
          // /restaurant_123/asdasd
          return await _get(request);
        }
      default:
        throw Exception('invalid ${request.path}');
    }
  }
}

class WebSocketFoodbServer extends FoodbServer {
  WebSocketFoodbServer(Foodb db) : super(db) {
    final handler = webSocketHandler((WebSocketChannel websocket) {
      websocket.stream.listen((message) async {
        print("echo $message");
        final result = await _handleRequest(Request.fromJson(message));
        websocket.sink.add({...result, 'messageId': message['messageId']});
      });
    });

    shelf_io.serve(handler, 'localhost', 6984).then((server) {
      print('Serving at ws://${server.address.host}:${server.port}');
    });
  }
}

void main(List<String> args) {
  Foodb db = Foodb.couchdb(dbName: '', baseUri: Uri());
  WebSocketFoodbServer(db);
}
