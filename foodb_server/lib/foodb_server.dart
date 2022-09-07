import 'package:foodb/foodb.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

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

  Future<dynamic> get(Request request);
}

class WebSocketFoodbServer implements FoodbServer {
  @override
  final Foodb db;
  WebSocketFoodbServer(this.db) {
    final handler = webSocketHandler((websocket) {
      websocket.stream.listen((message) async {
        final result = await _handleRequest(message);
        websocket.sink.add({...result, 'messageId': message['messageId']});
      });
    });

    shelf_io.serve(handler, 'localhost', 6984).then((server) {
      print('Serving at ws://${server.address.host}:${server.port}');
    });
  }

  _handleRequest(Map<String, dynamic> message) async {
    print("echo $message");
    final request = Request.fromJson(message);
    switch (request.path) {
      case 'get':
        {
          // /restaurant_123/asdasd
          return await get(request);
        }
      default:
        throw Exception('invalid ${request.path}');
    }
  }

  @override
  Future<dynamic> get(Request request) async {
    return db.get(id: request.path, fromJsonT: (v) => v);
  }
}

void main(List<String> args) {
  Foodb db = Foodb.couchdb(dbName: '', baseUri: Uri());
  WebSocketFoodbServer(db);
}
