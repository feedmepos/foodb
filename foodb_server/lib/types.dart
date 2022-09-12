import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/src/router_entry.dart';

class FoodbServerResponse {
  int? status;
  dynamic data;
  FoodbServerResponse({required this.data, this.status});
}

class FoodbRoute {
  String path;
  String method;
  Future<FoodbServerResponse> Function(FoodbServerRequest) _callback;
  FoodbRoute({
    required this.path,
    required this.method,
    required Future<FoodbServerResponse> Function(FoodbServerRequest) callback,
  }) : _callback = callback;

  Future<FoodbServerResponse> callback(FoodbServerRequest request) {
    return _callback(request.setRoute(this));
  }

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

  bool validate(FoodbServerRequest request) {
    return RouteMatcher.all(
      path: path,
      method: method,
      request: request,
    );
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
  String? body;
  String? messageId;
  FoodbRoute? route;
  String? type;
  String? authorization;
  FoodbServerRequest({
    required this.method,
    required this.uri,
    this.type,
    this.messageId,
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
      messageId: json['messageId'],
      type: json['type'],
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
