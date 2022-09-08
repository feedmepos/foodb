import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/src/router_entry.dart';

class RouteMatcher {
  static bool all({
    required String path,
    required String method,
    required FoodbRequest request,
  }) {
    final route = RouterEntry(method, path, () {});
    return method == request.method && route.match(request.uri.path) != null;
  }

  static bool get({
    required String path,
    required FoodbRequest request,
  }) {
    return RouteMatcher.all(method: 'GET', path: path, request: request);
  }

  static bool post({
    required String path,
    required FoodbRequest request,
  }) {
    return RouteMatcher.all(method: 'POST', path: path, request: request);
  }

  static bool put({
    required String path,
    required FoodbRequest request,
  }) {
    return RouteMatcher.all(method: 'PUT', path: path, request: request);
  }

  static bool delete({
    required String path,
    required FoodbRequest request,
  }) {
    return RouteMatcher.all(method: 'DELETE', path: path, request: request);
  }

  static bool head({
    required String path,
    required FoodbRequest request,
  }) {
    return RouteMatcher.all(method: 'HEAD', path: path, request: request);
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

class FoodbRequest {
  String method;
  Uri uri;
  String? body;
  String? messageId;
  FoodbRequest({
    required this.method,
    required this.uri,
    this.messageId,
    this.body,
  });

  Map<String, dynamic>? getParams(String path) {
    return RouterEntry(method, uri.path, () {}).match(path);
  }

  Map<String, dynamic>? get jsonBody {
    try {
      return jsonDecode(body ?? '');
    } catch (err) {
      return null;
    }
  }

  get queryParameters {
    return uri.queryParameters;
  }

  static FoodbRequest fromWebSocketMessage(String message) {
    final json = jsonDecode(message);
    return FoodbRequest(
      uri: Uri.parse(json['url']),
      body: json['body'],
      method: json['method'],
      messageId: json['messageId'],
    );
  }

  static FoodbRequest fromHttpRequest({
    required Request request,
    required String? body,
  }) {
    return FoodbRequest(
      uri: request.url,
      body: body,
      method: request.method,
    );
  }
}

class FoodbRoute {
  String path;
  String method;
  Future<dynamic> Function(FoodbRequest) callback;
  FoodbRoute({
    required this.path,
    required this.method,
    required this.callback,
  });

  factory FoodbRoute.get({
    required String path,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'GET', callback: callback);
  }

  bool validate(FoodbRequest request) {
    return RouteMatcher.all(
      path: path,
      method: method,
      request: request,
    );
  }
}

abstract class FoodbServer {
  final Foodb db;
  FoodbServer(this.db);

  Future<void> start();

  void initRoutes() {
    registerRoutes([
      FoodbRoute.get(path: '/<dbId>/_changes', callback: _changesStream),
    ]);
  }

  List<FoodbRoute> routes = [
    // if (RouteMatcher.get(path: '/<dbId>/_changes', request: request)) {
    //   // TODO: changes not implemented
    //   return _changesStream(request);
    // } else if (RouteMatcher.get(path: '/<dbId>/<docId>', request: request)) {
    //   return _get(request);
    // } else if (RouteMatcher.get(path: '', request: request)) {
    //   return _serverInfo(request);
    // } else if (RouteMatcher.get(path: '/<dbId>', request: request)) {
    //   return _info(request);
    // } else if (RouteMatcher.get(path: '/<dbId>/_all_docs', request: request)) {
    //   return _getAllDocs(request);
    // } else if (RouteMatcher.get(
    //     path: '/<dbId>/_design/<ddocId>/_view/<viewId>', request: request)) {
    //   return _getView(request);
    // }
    // if (RouteMatcher.post(path: '/<dbId>/_find', request: request)) {
    //   return _find(request);
    // } else if (RouteMatcher.post(path: '/<dbId>/_bulk_get', request: request)) {
    //   return _bulkGet(request);
    // } else if (RouteMatcher.post(
    //     path: '/<dbId>/_revs_diff', request: request)) {
    //   return _revsDiff(request);
    // } else if (RouteMatcher.post(path: '/<dbId>/_explain', request: request)) {
    //   return _explain(request);
    // } else if (RouteMatcher.post(
    //     path: '/<dbId>/_ensure_full_commit', request: request)) {
    //   return _ensureFullCommit(request);
    // } else if (RouteMatcher.post(path: '/<dbId>/_compact', request: request)) {
    //   return _compact(request);
    // } else if (RouteMatcher.post(path: '/<dbId>/_all_docs', request: request)) {
    //   return _postAllDocs(request);
    // } else if (RouteMatcher.post(path: '/<dbId>/_index', request: request)) {
    //   return _createIndex(request);
    // } else if (RouteMatcher.post(
    //     path: '/<dbId>/_design/<ddocId>/_view/<viewId>', request: request)) {
    //   return _postView(request);
    // }
    // if (RouteMatcher.put(path: '/<dbId>/_revs_limit', request: request)) {
    //   return _revsLimit(request);
    // } else if (RouteMatcher.put(path: '/<dbId>/<docId>', request: request)) {
    //   return _put(request);
    // }
    // if (RouteMatcher.delete(path: '/<dbId>', request: request)) {
    //   return _destroy(request);
    // } else if (RouteMatcher.delete(path: '/<dbId>/<docId>', request: request)) {
    //   return _delete(request);
    // } else if (RouteMatcher.delete(
    //     path: '/<dbId>/<ddocId>/json/<name>', request: request)) {
    //   return _deleteIndex(request);
    // }
    // if (RouteMatcher.head(path: '/<dbId>', request: request)) {
    //   return _initDb(request);
    // }
  ];

  void registerRoutes(List<FoodbRoute> newRoutes) {
    routes = [...routes, ...newRoutes];
  }

  Future<dynamic> handleRequest(FoodbRequest request) async {
    for (final route in routes) {
      final result = route.validate(request);
      if (result) {
        return await route.callback(request);
      } else {
        throw Exception('unknown request');
      }
    }
  }

  // db.get
  Future<dynamic> _get(FoodbRequest request) async {
    Map<String, dynamic> queryParameters = request.queryParameters;
    final docId = request.uri.pathSegments[1];
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

  // db.bulkGet
  Future<dynamic> _bulkGet(FoodbRequest request) async {
    final result = await db.bulkGet(
      body: BulkGetRequest.fromJson(request.jsonBody ?? {}),
      revs: parseBool(request.queryParameters['revs'], null),
      fromJsonT: (v) => v,
    );
    return result.toJson((v) => v);
  }

  // db.getAllDocs
  Future<dynamic> _getAllDocs(FoodbRequest request) async {
    final result = await db.allDocs(
      GetViewRequest.fromJson({}),
      (json) => json,
    );
    return result.toJson((value) => value);
  }

  // db.postAllDocs
  Future<dynamic> _postAllDocs(FoodbRequest request) async {
    final result = await db.allDocs(
      GetViewRequest.fromJson(request.jsonBody!),
      (json) => json,
    );
    return result.toJson((value) => value);
  }

  // db.bulkDocs
  Future<dynamic> bulkDocs(FoodbRequest request) async {
    final result = await db.bulkDocs(
      body: List.from(request.jsonBody?['docs'] ?? [])
          .map((doc) => Doc<Map<String, dynamic>>.fromJson(
              doc, (v) => v as Map<String, dynamic>))
          .toList(),
      newEdits: request.jsonBody?['new_edits'],
    );
    return result.toJson();
  }

  // db.changesStream
  Future<dynamic> _changesStream(FoodbRequest request) async {
    // TODO
    // final result = db.changesStream(ChangeRequest());
    // return result;
  }

  // db.compact
  Future<dynamic> _compact(FoodbRequest request) async {
    return await db.compact();
  }

  // db.createIndex
  Future<dynamic> _createIndex(FoodbRequest request) async {
    final queryParameters = request.queryParameters;
    final result = await db.createIndex(
      index: QueryViewOptionsDef.fromJson(
        jsonDecode(queryParameters['index'] ?? '{}'),
      ),
      ddoc: queryParameters['ddoc'],
      name: queryParameters['name'],
      type: queryParameters['type'] ?? 'json',
      partitioned: parseBool(queryParameters['partitioned'], null),
    );
    return result.toJson();
  }

  // db.delete
  Future<dynamic> _delete(FoodbRequest request) async {
    final docId = request.uri.pathSegments[1];
    final result = await db.delete(
      id: docId,
      rev: Rev.fromString(request.queryParameters['rev']),
    );
    return result.toJson();
  }

  // db.deleteIndex
  Future<dynamic> _deleteIndex(FoodbRequest request) async {
    final ddoc = request.uri.pathSegments[2];
    final name = request.uri.pathSegments.last;
    final result = await db.deleteIndex(
      ddoc: ddoc,
      name: name,
    );
    return result.toJson();
  }

  // db.destroy
  Future<dynamic> _destroy(FoodbRequest request) async {
    return db.destroy();
  }

  // db.ensureFullCommit
  Future<dynamic> _ensureFullCommit(FoodbRequest request) async {
    final result = await db.ensureFullCommit();
    return result.toJson();
  }

  // db.explain
  Future<dynamic> _explain(FoodbRequest request) async {
    final result =
        await db.explain(FindRequest.fromJson(request.jsonBody ?? {}));
    return result.toJson();
  }

  // db.fetchAllDesignDocs
  // Future<dynamic> _fetchAllDesignDocs(FoodbRequest request) async {
  //   final result = await db.fetchAllDesignDocs();
  //   return result.map((doc) => doc.toJson((value) => value)).toList();
  // }

  // db.fetchDesignDoc
  // Future<dynamic> _fetchDesignDoc(FoodbRequest request) async {
  //   return db.fetchDesignDoc(ddocName: request.jsonBody?['ddocName']);
  // }

  // db.find
  Future<dynamic> _find(FoodbRequest request) async {
    final body = request.jsonBody ?? {};
    final result = await db.find(FindRequest.fromJson(body), (v) => v);
    return result.toJson((value) => value);
  }

  // db.info
  Future<dynamic> _info(FoodbRequest request) async {
    final result = await db.info();
    return result.toJson();
  }

  // db.initDb
  Future<dynamic> _initDb(FoodbRequest request) async {
    return db.initDb();
  }

  // db.put
  Future<dynamic> _put(FoodbRequest request) async {
    final result = await db.put(
      doc: Doc.fromJson(
          request.jsonBody ?? {}, (json) => json as Map<String, dynamic>),
      newEdits: request.queryParameters['new_edits'],
    );
    return result.toJson();
  }

  // db.revsDiff
  Future<dynamic> _revsDiff(FoodbRequest request) async {
    final body = request.jsonBody?.entries.fold<Map<String, List<Rev>>>({},
            (result, entry) {
          result[entry.key] =
              entry.value.map((rev) => Rev.fromString(rev)).toList();
          return result;
        }) ??
        {};
    final result = await db.revsDiff(body: body);
    return result.entries.fold<Map<String, dynamic>>({}, (value, entry) {
      if (value[entry.key] == null) {
        value[entry.key] = {};
      }
      value[entry.key]['missing'] =
          entry.value.missing.map((e) => e.toString()).toList();
      value[entry.key]['possible_ancestors'] =
          entry.value.possibleAncestors ?? [];
      return value;
    });
  }

  // db.revsLimit
  Future<dynamic> _revsLimit(FoodbRequest request) async {
    final result = await db.revsLimit(int.parse(request.body!));
    return {
      "ok": result,
    };
  }

  // db.serverInfo
  Future<dynamic> _serverInfo(FoodbRequest request) async {
    final result = await db.serverInfo();
    return result.toJson();
  }

  // db.getView
  Future<dynamic> _getView(FoodbRequest request) async {
    final uri = request.uri;
    final params = request.getParams('/<dbId>/_design/<ddocId>/_view/<viewId>');
    final ddocId = params?['ddocId'];
    final viewId = params?['viewId'];
    final result = await db.view(
      ddocId,
      viewId,
      GetViewRequest.fromJson(uri.queryParameters),
      (json) => json,
    );
    return result.toJson((value) => value);
  }

  // db.postView
  Future<dynamic> _postView(FoodbRequest request) async {
    final uri = request.uri;
    final docId = uri.pathSegments[1];
    final viewId = uri.pathSegments.last;
    final result = await db.view(
      docId,
      viewId,
      GetViewRequest.fromJson({
        ...request.queryParameters,
        ...(request.jsonBody ?? {}),
      }),
      (json) => json,
    );
    return result.toJson((value) => value);
  }
}
