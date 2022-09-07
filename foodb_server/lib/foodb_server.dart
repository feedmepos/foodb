import 'package:foodb/foodb.dart';

class FoodbRequest {
  String method;
  Uri url;
  Map<String, dynamic>? body;
  FoodbRequest({
    required this.method,
    required this.url,
    this.body,
  });

  get queryParameters {
    return url.queryParameters;
  }

  get name {
    if (method == 'GET') {
      if (url.pathSegments.length == 2) {
        if (url.path.contains('_bulk_get')) {
          // {db}/_bulk_get
          return 'bulkGet';
        } else {
          // {db}/{doc}
          return 'get';
        }
      } else {
        throw Exception('unknown request');
      }
    } else {
      throw Exception('unknown request');
    }
  }

  static FoodbRequest fromWebSocketMessage(Map<String, dynamic> message) {
    return FoodbRequest(
      url: Uri.parse(message['url']),
      body: message['body'],
      method: message['method'],
    );
  }
}

abstract class FoodbServer {
  final Foodb db;
  FoodbServer(this.db);

  Future<Map<String, dynamic>?> _get(FoodbRequest request) async {
    Map<String, dynamic> queryParameters = request.queryParameters;
    final docId = request.url.pathSegments[1];
    final result = await db.get(
      id: docId,
      attachments: queryParameters['attachments'] ?? false,
      attEncodingInfo: queryParameters['attEncodingInfo'] ?? false,
      attsSince: queryParameters['attsSince'],
      conflicts: queryParameters['conflicts'] ?? false,
      deletedConflicts: queryParameters['deletedConflicts'] ?? false,
      latest: queryParameters['latest'] ?? false,
      localSeq: queryParameters['localSeq'] ?? false,
      meta: queryParameters['meta'] ?? false,
      rev: queryParameters['rev'],
      revs: queryParameters['revs'] ?? false,
      revsInfo: queryParameters['revsInfo'] ?? false,
      fromJsonT: (v) => v,
    );
    return result?.toJson((v) => v);
  }

  Future<dynamic> _bulkGet(FoodbRequest request) async {
    return db.bulkGet(body: BulkGetRequest(docs: []), fromJsonT: (v) => v);
  }

  Future<Map<String, dynamic>?> handleRequest(FoodbRequest request) async {
    switch (request.name) {
      case 'get':
        return await _get(request);
      case 'bulkGet':
        return await _bulkGet(request);
      default:
        throw Exception('invalid ${request.url.path}');
    }
  }
}

// void main(List<String> args) {
//   Foodb db = Foodb.couchdb(dbName: '', baseUri: Uri());
//   WebSocketFoodbServer(db);
// }
