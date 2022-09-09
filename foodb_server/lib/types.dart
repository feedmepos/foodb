import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/src/router_entry.dart';

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

class FoodbRequest {
  String method;
  Uri uri;
  String? body;
  String? messageId;
  FoodbRoute? route;
  String? type;
  FoodbRequest({
    required this.method,
    required this.uri,
    this.type,
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

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'uri': uri,
      'body': body,
      'messageId': messageId,
      'route': route,
      'type': type,
    };
  }

  static FoodbRequest fromWebSocketMessage(String message) {
    final json = jsonDecode(message);
    return FoodbRequest(
      uri: Uri.parse(json['url']),
      body: json['body'],
      method: json['method'],
      messageId: json['messageId'],
      type: json['type'],
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
