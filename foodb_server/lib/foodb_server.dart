import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:shelf/shelf.dart';

class FoodbRequest {
  String method;
  Uri url;
  Map<String, dynamic>? body;
  String? messageId;
  FoodbRequest({
    required this.method,
    required this.url,
    this.messageId,
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

  static FoodbRequest fromWebSocketMessage(String message) {
    final json = jsonDecode(message);
    return FoodbRequest(
      url: Uri.parse(json['url']),
      body: json['body'],
      method: json['method'],
      messageId: json['messageId'],
    );
  }

  static FoodbRequest fromHttpRequest({
    required Request request,
    required Map<String, dynamic> body,
  }) {
    return FoodbRequest(
      url: request.url,
      body: body,
      method: request.method,
    );
  }
}

bool parseBool(dynamic value, bool? fallback) {
  if (value == 'true') {
    return true;
  } else if (value == 'false') {
    return false;
  } else if (value == null) {
    return fallback ?? value;
  } else {
    return value;
  }
}

abstract class FoodbServer {
  final Foodb db;
  FoodbServer(this.db);

  Future<void> start();

  Future<Map<String, dynamic>?> _get(FoodbRequest request) async {
    Map<String, dynamic> queryParameters = request.queryParameters;
    final docId = request.url.pathSegments[1];
    final result = await db.get(
      id: docId,
      attachments: parseBool(queryParameters['attachments'], false),
      attEncodingInfo: parseBool(queryParameters['attEncodingInfo'], false),
      attsSince: queryParameters['attsSince'],
      conflicts: parseBool(queryParameters['conflicts'], false),
      deletedConflicts: parseBool(queryParameters['deletedConflicts'], false),
      latest: parseBool(queryParameters['latest'], false),
      localSeq: parseBool(queryParameters['localSeq'], false),
      meta: parseBool(queryParameters['meta'], false),
      rev: queryParameters['rev'],
      revs: parseBool(queryParameters['revs'], false),
      revsInfo: parseBool(queryParameters['revsInfo'], false),
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
