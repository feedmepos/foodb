import 'dart:async';
import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/src/router_entry.dart';

class RouteMatcher {
  static Map<String, dynamic>? getPathParams({
    required String path,
    required Uri uri,
  }) {
    return RouterEntry('', path, () {}).match(uri.path);
  }

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

bool parseBool(dynamic value) {
  if (value == 'true') {
    return true;
  } else if (value == 'false') {
    return false;
  } else {
    return value;
  }
}

bool _isNumeric(String? str) {
  if (str == null) {
    return false;
  }
  return double.tryParse(str) != null;
}

bool _isInt(String? str) {
  if (str == null) {
    return false;
  }
  return int.tryParse(str) != null;
}

dynamic parseQueryParams(dynamic value) {
  if (value == 'true' || value == 'false') {
    return parseBool(value);
  } else if (_isNumeric(value)) {
    return num.parse(value);
  } else if (_isInt(value)) {
    return int.parse(value);
  } else {
    return value;
  }
}

class FoodbRequest {
  String method;
  Uri uri;
  String? body;
  String? messageId;
  FoodbRoute? route;
  FoodbRequest({
    required this.method,
    required this.uri,
    this.messageId,
    this.body,
  });

  FoodbRequest setRoute(FoodbRoute newRoute) {
    route = newRoute;
    return this;
  }

  Map<String, dynamic>? get pathParams {
    return RouteMatcher.getPathParams(path: route!.path, uri: uri);
  }

  Map<String, dynamic>? get jsonBody {
    try {
      return jsonDecode(body ?? '');
    } catch (err) {
      return null;
    }
  }

  Map<String, dynamic> get queryParams {
    return uri.queryParameters.entries.fold<Map<String, dynamic>>({},
        (result, entry) {
      result[entry.key] = parseQueryParams(entry.value);
      return result;
    });
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
      uri: request.requestedUri,
      body: body,
      method: request.method,
    );
  }
}

class FoodbRoute {
  String path;
  String method;
  Future<dynamic> Function(FoodbRequest) _callback;
  FoodbRoute({
    required this.path,
    required this.method,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) : _callback = callback;

  Future<dynamic> callback(FoodbRequest request) {
    return _callback(request.setRoute(this));
  }

  factory FoodbRoute.get({
    required String path,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'GET', callback: callback);
  }

  factory FoodbRoute.post({
    required String path,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'POST', callback: callback);
  }

  factory FoodbRoute.put({
    required String path,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'PUT', callback: callback);
  }

  factory FoodbRoute.delete({
    required String path,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'DELETE', callback: callback);
  }

  factory FoodbRoute.head({
    required String path,
    required Future<dynamic> Function(FoodbRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'HEAD', callback: callback);
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

  Future<void> start() async {
    setRoutes([
      FoodbRoute.get(path: '/<dbId>/_changes', callback: _changesStream),
      FoodbRoute.get(path: '/<dbId>/<docId>', callback: _get),
      FoodbRoute.get(path: '/', callback: _serverInfo),
      FoodbRoute.get(path: '/<dbId>', callback: _info),
      FoodbRoute.get(path: '/<dbId>/_all_docs', callback: _allDocs),
      FoodbRoute.get(
          path: '/<dbId>/_design/<ddocId>/_view/<viewId>', callback: _view),
      FoodbRoute.post(path: '/<dbId>/_find', callback: _find),
      FoodbRoute.post(path: '/<dbId>/_bulk_get', callback: _bulkGet),
      FoodbRoute.post(path: '/<dbId>/_revs_diff', callback: _revsDiff),
      FoodbRoute.post(path: '/<dbId>/_explain', callback: _explain),
      FoodbRoute.post(
          path: '/<dbId>/_ensure_full_commit', callback: _ensureFullCommit),
      FoodbRoute.post(path: '/<dbId>/_compact', callback: _compact),
      FoodbRoute.post(path: '/<dbId>/_all_docs', callback: _allDocs),
      FoodbRoute.post(path: '/<dbId>/_index', callback: _createIndex),
      FoodbRoute.post(
          path: '/<dbId>/_design/<ddocId>/_view/<viewId>', callback: _view),
      FoodbRoute.put(path: '/<dbId>/_revs_limit', callback: _revsLimit),
      FoodbRoute.put(path: '/<dbId>/<docId>', callback: _put),
      FoodbRoute.delete(path: '/<dbId>', callback: _destroy),
      FoodbRoute.delete(path: '/<dbId>/<docId>', callback: _delete),
      FoodbRoute.delete(
          path: '/<dbId>/_index/<ddocId>/json/<name>', callback: _deleteIndex),
      FoodbRoute.head(path: '/<dbId>', callback: _initDb),
    ]);
  }

  List<FoodbRoute> routes = [];

  void setRoutes(List<FoodbRoute> newRoutes) {
    routes = [...newRoutes];
  }

  Future<dynamic> handleRequest(FoodbRequest request) async {
    for (final route in routes) {
      final result = route.validate(request);
      if (result) {
        return await route.callback(request);
      }
    }
    throw Exception('unknown request');
  }

  // db.get
  Future<dynamic> _get(FoodbRequest request) async {
    Map<String, dynamic> queryParams = request.queryParams;
    final result = await db.get(
      id: request.pathParams?['docId'],
      attachments: queryParams['attachments'] ?? false,
      attEncodingInfo: queryParams['attEncodingInfo'] ?? false,
      attsSince: queryParams['attsSince'],
      conflicts: queryParams['conflicts'] ?? false,
      deletedConflicts: queryParams['deletedConflicts'] ?? false,
      latest: queryParams['latest'] ?? false,
      localSeq: queryParams['localSeq'] ?? false,
      meta: queryParams['meta'] ?? false,
      rev: queryParams['rev'],
      revs: queryParams['revs'] ?? false,
      revsInfo: queryParams['revsInfo'] ?? false,
      fromJsonT: (v) => v,
    );
    return result?.toJson((v) => v);
  }

  // db.bulkGet
  Future<dynamic> _bulkGet(FoodbRequest request) async {
    final result = await db.bulkGet(
      body: BulkGetRequest.fromJson(request.jsonBody ?? {}),
      revs: request.queryParams['revs'],
      fromJsonT: (v) => v,
    );
    return result.toJson((v) => v);
  }

  // db.allDocs
  Future<dynamic> _allDocs(FoodbRequest request) async {
    final result = await db.allDocs(
      GetViewRequest.fromJson(request.jsonBody ?? {}),
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
    /**
     * normal, onComplete
     * long poll, onResult -> onComplete
     * continuous, onResult -> onResult -> onResult
     */
    final changesRequest = ChangeRequest.fromJson({
      ...request.queryParams,
      'since': request.queryParams['since'].toString(),
    });
    final streamController = StreamController<List<int>>();
    db.changesStream(
      changesRequest,
      onComplete: (response) {
        streamController.sink.add(jsonEncode(response.toJson()).codeUnits);
        streamController.close();
      },
      onResult: (response) {
        streamController.sink.add(jsonEncode(response.toJson()).codeUnits);
      },
      onError: (error, stacktrace) {
        throw Exception(error);
      },
    );
    return streamController.stream;
  }

  // db.compact
  Future<dynamic> _compact(FoodbRequest request) async {
    return await db.compact();
  }

  // db.createIndex
  Future<dynamic> _createIndex(FoodbRequest request) async {
    final queryParams = request.queryParams;
    final result = await db.createIndex(
      index: QueryViewOptionsDef.fromJson(
        jsonDecode(queryParams['index'] ?? '{}'),
      ),
      ddoc: queryParams['ddoc'],
      name: queryParams['name'],
      type: queryParams['type'] ?? 'json',
      partitioned: queryParams['partitioned'],
    );
    return result.toJson();
  }

  // db.delete
  Future<dynamic> _delete(FoodbRequest request) async {
    final result = await db.delete(
      id: request.pathParams?['docId'],
      rev: Rev.fromString(request.queryParams['rev']),
    );
    return result.toJson();
  }

  // db.deleteIndex
  Future<dynamic> _deleteIndex(FoodbRequest request) async {
    final result = await db.deleteIndex(
      ddoc: request.pathParams?['ddocId'],
      name: request.pathParams?['name'],
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
      newEdits: request.queryParams['new_edits'],
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

  // db.view
  Future<dynamic> _view(FoodbRequest request) async {
    final result = await db.view(
      request.pathParams?['ddocId'],
      request.pathParams?['viewId'],
      GetViewRequest.fromJson({
        ...request.queryParams,
        ...(request.jsonBody ?? {}),
      }),
      (json) => json,
    );
    return result.toJson((value) => value);
  }
}
