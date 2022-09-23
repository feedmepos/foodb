import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_server/foodb_server.dart';
import 'mock_data.dart';
import 'ssl/ssl_certs.dart';

class HttpTrustSelfSignOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = Duration(milliseconds: 3000)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

SecurityContext getSecurityContext() {
  final certChainBytes = getCertChainBytes();
  final certKeyBytes = getCertKeyBytes();

  return SecurityContext()
    ..setTrustedCertificatesBytes(certChainBytes)
    ..useCertificateChainBytes(certChainBytes)
    ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');
}

testFn(Future<void> Function(Foodb) fn) async {
  load('.env');
  final ctx = ServerTestContext();

  final httpServerPortNo = int.parse(env['DEV_HTTP_SERVER_PORT_NO'] ?? '6987');
  final websocketServerPortNo =
      int.parse(env['DEV_WEBSOCKET_SERVER_PORT_NO'] ?? '6988');

  var types = [
    {
      'client': (String dbName) => Foodb.couchdb(
            dbName: dbName,
            baseUri: Uri.parse(
                'https://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:$httpServerPortNo'),
          ),
      'server': (
        Future<Foodb> Function(String) dbFactory,
        FoodbServerConfig config,
      ) =>
          HttpFoodbServer(
            dbFactory: dbFactory,
            config: config,
          ),
      'port': httpServerPortNo,
    },
    {
      'client': (String dbName) => Foodb.websocket(
            dbName: dbName,
            baseUri: Uri.parse(
                'wss://${ctx.fooDbUsername}:${ctx.fooDbPassword}@127.0.0.1:$websocketServerPortNo'),
          ),
      'server': (
        Future<Foodb> Function(String) dbFactory,
        FoodbServerConfig config,
      ) =>
          WebSocketFoodbServer(
            dbFactory: dbFactory,
            config: config,
          ),
      'port': websocketServerPortNo,
    },
  ];

  for (final type in types) {
    final server = (type['server'] as dynamic)(
      (dbName) async {
        final db = Foodb.keyvalue(
          dbName: dbName,
          keyValueDb: KeyValueAdapter.inMemory(),
        );
        await db.bulkDocs(body: mockDocs);
        return db;
      },
      FoodbServerConfig(
        auths: [
          DatabaseAuth(
            database: ctx.dbId,
            username: ctx.fooDbUsername,
            password: ctx.fooDbPassword,
          )
        ],
        securityContext: getSecurityContext(),
      ),
    );

    await server.start(port: type['port']);

    final client = (type['client'] as dynamic)(ctx.dbId);

    await fn(client);
    await server.stop();
  }
}
