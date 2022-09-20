part of './abstract_foodb_server.dart';

FutureOr<Response> Function(Request) Function(
    FutureOr<Response> Function(Request)) getCorsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  };
  Response? options(Request request) => (request.method == 'OPTIONS')
      ? Response.ok(null, headers: corsHeaders)
      : null;
  Response cors(Response response) => response.change(headers: corsHeaders);
  return createMiddleware(requestHandler: options, responseHandler: cors);
}

class HttpFoodbServer extends FoodbServer {
  HttpFoodbServer({
    required Future<Foodb> Function(String dbName) dbFactory,
    FoodbServerConfig? config,
  }) : super(dbFactory: dbFactory, config: config);
  HttpServer? _server;

  @override
  Future<void> start({int? port}) async {
    int serverPort = getServerPort(port: port);

    await super.init();
    final router = Router();
    final handler = Pipeline()
        .addMiddleware(getCorsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router);
    router.mount('/', (Request req) async {
      try {
        final bodyString = await req.readAsString();
        final request =
            FoodbServerRequest.fromHttpRequest(request: req, body: bodyString);
        final response = await handleRequest(request);
        if (response.data is Stream<List<int>>) {
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
      } catch (err) {
        return Response(
          500,
          body: jsonEncode(err.toString()),
        );
      }
    });

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      serverPort,
      securityContext: config?.securityContext,
    );
    print('Serving at http://${_server?.address.host}:$serverPort');
  }

  @override
  Future<void> stop() async {
    await _server?.close();
  }
}
