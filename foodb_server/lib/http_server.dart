import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:foodb_server/foodb_server.dart';
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

  @override
  Future<void> start({int port = 6984}) async {
    final router = Router();
    final handler = Pipeline()
        .addMiddleware(getCorsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router);
    router.all('/<.*>', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final request = FoodbRequest.fromHttpRequest(request: req, body: body);
      return await handleRequest(request);
    });

    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('Serving at ws://${server.address.host}:${server.port}');
  }
}
