import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:foodb_server/types.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:foodb_server/abstract_foodb_server.dart';
import 'package:foodb/foodb.dart';

FutureOr<Response> Function(Request) Function(
    FutureOr<Response> Function(Request)) getCorsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  };
  Response? _options(Request request) => (request.method == 'OPTIONS')
      ? Response.ok(null, headers: corsHeaders)
      : null;
  Response _cors(Response response) => response.change(headers: corsHeaders);
  return createMiddleware(requestHandler: _options, responseHandler: _cors);
}

class HttpFoodbServer extends FoodbServer {
  HttpFoodbServer(Foodb db) : super(db);
  HttpServer? _server;

  @override
  Future<void> start({int port = 6984}) async {
    await super.start();
    final router = Router();
    final handler = Pipeline()
        .addMiddleware(getCorsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router);
    router.mount('/', (Request req) async {
      final bodyString = await req.readAsString();
      final request =
          FoodbServerRequest.fromHttpRequest(request: req, body: bodyString);
      final response = await handleRequest(request);
      if (response is Stream<List<int>>) {
        return Response(
          response.status ?? 200,
          body: response.data,
          context: {"shelf.io.buffer_output": false},
        );
      } else {
        return Response(
          response.status ?? 200,
          body: jsonEncode(response.data),
        );
      }
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('Serving at http://${_server?.address.host}:${_server?.port}');
  }

  @override
  Future<void> stop() async {
    _server?.close();
  }
}
