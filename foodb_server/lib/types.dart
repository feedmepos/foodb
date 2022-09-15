import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/src/router_entry.dart';

class DatabaseAuth {
  String database;
  String username;
  String password;
  DatabaseAuth({
    required this.database,
    required this.username,
    required this.password,
  });

  String get _authorization =>
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  bool validate(String? authorization) {
    return _authorization == authorization;
  }
}

class FoodbServerConfig {
  List<DatabaseAuth> auths;
  SecurityContext? securityContext;
  FoodbServerConfig({
    required this.auths,
    this.securityContext,
  });
}

class FoodbServerResponse {
  int? status;
  dynamic data;
  FoodbServerResponse({required this.data, this.status});
}

class FoodbRoute {
  String path;
  String method;
  Future<FoodbServerResponse> Function(FoodbServerRequest) callback;
  FoodbRoute({
    required this.path,
    required this.method,
    required this.callback,
  });

  factory FoodbRoute.get({
    required String path,
    required Future<FoodbServerResponse> Function(FoodbServerRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'GET', callback: callback);
  }

  factory FoodbRoute.post({
    required String path,
    required Future<FoodbServerResponse> Function(FoodbServerRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'POST', callback: callback);
  }

  factory FoodbRoute.put({
    required String path,
    required Future<FoodbServerResponse> Function(FoodbServerRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'PUT', callback: callback);
  }

  factory FoodbRoute.delete({
    required String path,
    required Future<FoodbServerResponse> Function(FoodbServerRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'DELETE', callback: callback);
  }

  factory FoodbRoute.head({
    required String path,
    required Future<FoodbServerResponse> Function(FoodbServerRequest) callback,
  }) {
    return FoodbRoute(path: path, method: 'HEAD', callback: callback);
  }

  FoodbServerRequest? validate(FoodbServerRequest request) {
    final result = RouteMatcher.all(
      path: path,
      method: method,
      request: request,
    );
    if (result) {
      return request.setRoute(this);
    } else {
      return null;
    }
  }
}

extension ElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) {
    try {
      return this[index];
    } catch (err) {
      return null;
    }
  }
}

class FoodbServerRequest {
  String method;
  Uri uri;
  dynamic body;
  String? id;
  FoodbRoute? route;
  bool hold;
  String? authorization;
  FoodbServerRequest({
    required this.method,
    required this.uri,
    this.hold = false,
    this.id,
    this.body,
    this.authorization,
  });

  FoodbServerRequest setRoute(FoodbRoute newRoute) {
    route = newRoute;
    return this;
  }

  Map<String, dynamic>? get pathParams {
    return RouteMatcher.getPathParams(path: route!.path, uri: uri);
  }

  dynamic get jsonBody {
    try {
      if (body is String) {
        return jsonDecode(body);
      } else {
        return body;
      }
    } catch (err) {
      return null;
    }
  }

  Map<String, dynamic> get queryParams {
    return uri.queryParameters.entries.fold<Map<String, dynamic>>({},
        (result, entry) {
      try {
        result[entry.key] = jsonDecode(entry.value);
      } catch (err) {
        result[entry.key] = entry.value;
      }
      return result;
    });
  }

  static FoodbServerRequest fromWebSocketMessage(String message) {
    final json = jsonDecode(message);
    final uri = Uri.parse(json['url']);
    final userInfo = uri.userInfo.split(':');
    final username = userInfo.elementAtOrNull(0);
    final password = userInfo.elementAtOrNull(1);
    return FoodbServerRequest(
      uri: Uri.parse(json['url']),
      body: json['body'],
      method: json['method'],
      id: json['id'],
      hold: json['hold'],
      authorization: (username != null || password != null)
          ? 'Basic ${base64.encode(utf8.encode('$username:$password'))}'
          : null,
    );
  }

  static FoodbServerRequest fromHttpRequest({
    required Request request,
    required String? body,
  }) {
    return FoodbServerRequest(
      uri: request.requestedUri,
      body: body,
      method: request.method,
      authorization: request.headers['authorization'],
    );
  }
}

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
    required FoodbServerRequest request,
  }) {
    final route = RouterEntry(method, path, () {});
    var uriPath = request.uri.path;
    if (uriPath.length > 1 && uriPath.endsWith('/')) {
      uriPath = uriPath.substring(0, uriPath.length - 1);
    }
    return method == request.method && route.match(uriPath) != null;
  }

  static bool get({
    required String path,
    required FoodbServerRequest request,
  }) {
    return RouteMatcher.all(method: 'GET', path: path, request: request);
  }

  static bool post({
    required String path,
    required FoodbServerRequest request,
  }) {
    return RouteMatcher.all(method: 'POST', path: path, request: request);
  }

  static bool put({
    required String path,
    required FoodbServerRequest request,
  }) {
    return RouteMatcher.all(method: 'PUT', path: path, request: request);
  }

  static bool delete({
    required String path,
    required FoodbServerRequest request,
  }) {
    return RouteMatcher.all(method: 'DELETE', path: path, request: request);
  }

  static bool head({
    required String path,
    required FoodbServerRequest request,
  }) {
    return RouteMatcher.all(method: 'HEAD', path: path, request: request);
  }
}
