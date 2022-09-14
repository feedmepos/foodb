import 'dart:async';
import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:foodb_server/types.dart';
import 'package:collection/collection.dart';

abstract class FoodbServer {
  final Future<Foodb> Function(String dbName) dbFactory;
  final FoodbServerConfig? config;
  Map<String, Foodb> dbs = {};
  FoodbServer({
    required this.dbFactory,
    required this.config,
  });

  Future<Foodb> _getDb(FoodbServerRequest request) async {
    final dbId = request.pathParams?['dbId'] ?? '';
    if (!dbs.containsKey(dbId)) {
      final db = await dbFactory(dbId);
      dbs[dbId] = db;
    }
    return dbs[dbId]!;
  }

  int getServerPort({required int? port}) {
    if (port == null) {
      return config?.securityContext == null ? 6984 : 7984;
    }
    return port;
  }

  Future<void> start({int port = 6984});

  Future<void> init() async {
    setRoutes([
      FoodbRoute.get(path: '/<dbId>', callback: _info),
      FoodbRoute.get(path: '/<dbId>/_changes', callback: _changesStream),
      FoodbRoute.get(path: '/', callback: _serverInfo),
      FoodbRoute.get(path: '/<dbId>/_all_docs', callback: _allDocs),
      FoodbRoute.get(
          path: '/<dbId>/_design/<ddocId>/_view/<viewId>', callback: _view),
      FoodbRoute.post(path: '/<dbId>/_find', callback: _find),
      FoodbRoute.post(path: '/<dbId>/_bulk_get', callback: _bulkGet),
      FoodbRoute.post(path: '/<dbId>/_bulk_docs', callback: _bulkDocs),
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
      FoodbRoute.delete(path: '/<dbId>', callback: _destroy),
      FoodbRoute.delete(
          path: '/<dbId>/_index/<ddocId>/json/<name>', callback: _deleteIndex),
      FoodbRoute.head(path: '/<dbId>', callback: _initDb),
      FoodbRoute.delete(path: '/<dbId>/<docId>', callback: _delete),
      FoodbRoute.put(
          path: '/<dbId>/<docId>', callback: (request) => _put(request)),
      FoodbRoute.put(
          path: '/<dbId>/_local/<docId>',
          callback: (request) => _put(request, prefix: '_local')),
      FoodbRoute.get(path: '/<dbId>/<docId>', callback: _get),
      FoodbRoute.get(
          path: '/<dbId>/_design/<docId>',
          callback: (request) => _get(request, prefix: '_design')),
      FoodbRoute.get(
          path: '/<dbId>/_local/<docId>',
          callback: (request) => _get(request, prefix: '_local')),
    ]);
  }

  Future<void> stop();

  List<FoodbRoute> routes = [];

  void setRoutes(List<FoodbRoute> newRoutes) {
    routes = [...newRoutes];
  }

  bool authorize(FoodbServerRequest request) {
    final dbId = request.pathParams?['dbId'];
    final auth =
        config?.auths.firstWhereOrNull((auth) => auth.database == dbId);
    if (auth == null) {
      return true;
    } else {
      return auth.validate(request.authorization);
    }
  }

  Future<FoodbServerResponse> handleRequest(FoodbServerRequest request) async {
    for (final route in routes) {
      final validatedRequest = route.validate(request);
      if (validatedRequest != null) {
        try {
          final valid = authorize(validatedRequest);
          if (!valid) {
            return FoodbServerResponse(
              status: 401,
              data: {"error": 'unauthorized', "reason": 'unauthorized'},
            );
          }
          return await route.callback(validatedRequest);
        } catch (err) {
          if (err is AdapterException) {
            return FoodbServerResponse(
              status: 400,
              data: {"error": err.error, "reason": err.reason},
            );
          } else {
            return FoodbServerResponse(
              status: 500,
              data: {
                "error": "internal server error",
                "reason": err.toString()
              },
            );
          }
        }
      }
    }
    return FoodbServerResponse(
      status: 404,
      data: {"error": "route not found", "reason": "route not found"},
    );
  }

  Future<FoodbServerResponse> _get(
    FoodbServerRequest request, {
    String? prefix,
  }) async {
    Map<String, dynamic> queryParams = request.queryParams;
    String id = request.pathParams?['docId'] ?? '';
    if (prefix != null) {
      id = '$prefix/$id';
    }
    try {
      final result = await (await _getDb(request)).get(
        id: id,
        attachments: queryParams['attachments'] ?? false,
        attEncodingInfo: queryParams['att_encoding_info'] ?? false,
        attsSince: queryParams['atts_since'],
        conflicts: queryParams['conflicts'] ?? false,
        deletedConflicts: queryParams['deleted_conflicts'] ?? false,
        latest: queryParams['latest'] ?? false,
        localSeq: queryParams['local_seq'] ?? false,
        meta: queryParams['meta'] ?? false,
        rev: queryParams['rev'],
        revs: queryParams['revs'] ?? false,
        revsInfo: queryParams['revs_info'] ?? false,
        fromJsonT: (v) => v,
      );
      return FoodbServerResponse(
        data: result != null
            ? result.toJson((v) => v, fullMeta: true)
            : {
                "error": "not_found",
                "reason": "missing",
              },
      );
    } catch (err) {
      return FoodbServerResponse(data: {
        "error": "not_found",
        "reason": "missing",
      });
    }
  }

  Future<FoodbServerResponse> _bulkGet(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).bulkGet(
      body: BulkGetRequest.fromJson(request.jsonBody ?? {}),
      revs: request.queryParams['revs'],
      fromJsonT: (v) => v,
    );
    return FoodbServerResponse(data: result.toJson((v) => v));
  }

  Future<FoodbServerResponse> _allDocs(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).allDocs(
      GetViewRequest.fromJson(
          {...request.queryParams, ...(request.jsonBody ?? {})}),
      (json) => json,
    );
    return FoodbServerResponse(data: result.toJson((v) => v));
  }

  Future<FoodbServerResponse> _bulkDocs(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).bulkDocs(
      body: List.from(request.jsonBody?['docs'] ?? [])
          .map((doc) => Doc<Map<String, dynamic>>.fromJson(
              doc, (v) => v as Map<String, dynamic>))
          .toList(),
      newEdits: request.jsonBody?['new_edits'],
    );
    return FoodbServerResponse(
      status: 201,
      data: result.putResponses.map((v) => v.toJson()).toList(),
    );
  }

  Future<FoodbServerResponse> _changesStream(FoodbServerRequest request) async {
    /**
     * normal, onComplete
     * long poll, onResult -> onComplete
     * continuous, onResult -> onResult -> onResult
     */
    // TODO: handle heartbeat?
    final changesRequest = ChangeRequest.fromJson({
      ...request.queryParams,
      'since': request.queryParams['since'].toString(),
    });
    final streamController = StreamController<List<int>>();
    (await _getDb(request)).changesStream(
      changesRequest,
      onComplete: (response) {
        if (changesRequest.feed == ChangeFeed.normal ||
            changesRequest.feed == ChangeFeed.longpoll) {
          streamController.sink.add(jsonEncode(response.toJson()).codeUnits);
          streamController.close();
        }
      },
      onResult: (response) {
        if (changesRequest.feed == ChangeFeed.continuous) {
          streamController.sink.add(jsonEncode(response.toJson()).codeUnits);
        }
      },
      onError: (error, stacktrace) {
        streamController.close();
      },
    );
    return FoodbServerResponse(data: streamController.stream);
  }

  Future<FoodbServerResponse> _compact(FoodbServerRequest request) async {
    return FoodbServerResponse(data: (await (await _getDb(request)).compact()));
  }

  Future<FoodbServerResponse> _createIndex(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).createIndex(
      index: QueryViewOptionsDef.fromJson(
        request.jsonBody?['index'] ?? {},
      ),
      ddoc: request.jsonBody?['ddoc'],
      name: request.jsonBody?['name'],
      type: request.jsonBody?['type'] ?? 'json',
      partitioned: request.jsonBody?['partitioned'],
    );
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _delete(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).delete(
      id: request.pathParams?['docId'],
      rev: Rev.fromString(request.queryParams['rev']),
    );
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _deleteIndex(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).deleteIndex(
      ddoc: request.pathParams?['ddocId'],
      name: request.pathParams?['name'],
    );
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _destroy(FoodbServerRequest request) async {
    return FoodbServerResponse(data: (await (await _getDb(request)).destroy()));
  }

  Future<FoodbServerResponse> _ensureFullCommit(
      FoodbServerRequest request) async {
    final result = await (await _getDb(request)).ensureFullCommit();
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _explain(FoodbServerRequest request) async {
    final result = await (await _getDb(request))
        .explain(FindRequest.fromJson(request.jsonBody ?? {}));
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _find(FoodbServerRequest request) async {
    final body = request.jsonBody ?? {};
    final result = await (await _getDb(request))
        .find(FindRequest.fromJson(body), (v) => v);
    return FoodbServerResponse(data: result.toJson((v) => v));
  }

  Future<FoodbServerResponse> _info(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).info();
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _initDb(FoodbServerRequest request) async {
    return FoodbServerResponse(data: (await (await _getDb(request)).initDb()));
  }

  Future<FoodbServerResponse> _put(
    FoodbServerRequest request, {
    String? prefix,
  }) async {
    String id = request.pathParams?['docId'] ?? '';
    if (prefix != null) {
      id = '$prefix/$id';
    }
    final result = await (await _getDb(request)).put(
      doc: Doc.fromJson({"_id": id, ...request.jsonBody ?? {}},
          (json) => json as Map<String, dynamic>),
      newEdits: request.queryParams['new_edits'],
    );
    final v = await (await _getDb(request)).get(id: id, fromJsonT: (v) => v);
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _revsDiff(FoodbServerRequest request) async {
    Map<String, List<String>> temp = {};
    for (final key in Map<String, dynamic>.from(request.jsonBody).keys) {
      temp[key] = List<String>.from(request.jsonBody[key]);
    }
    final body = temp.entries.fold<Map<String, List<Rev>>>({}, (result, entry) {
      result[entry.key] =
          entry.value.map<Rev>((rev) => Rev.fromString(rev)).toList();
      return result;
    });
    final result = await (await _getDb(request)).revsDiff(body: body);
    final data = result.entries.fold<Map<String, dynamic>>({}, (value, entry) {
      if (value[entry.key] == null) {
        value[entry.key] = {};
      }
      value[entry.key]['missing'] =
          entry.value.missing.map((e) => e.toString()).toList();
      value[entry.key]['possible_ancestors'] =
          entry.value.possibleAncestors ?? [];
      return value;
    });
    return FoodbServerResponse(data: data);
  }

  Future<FoodbServerResponse> _revsLimit(FoodbServerRequest request) async {
    final result =
        await (await _getDb(request)).revsLimit(int.parse(request.body!));
    return FoodbServerResponse(data: {
      "ok": result,
    });
  }

  Future<FoodbServerResponse> _serverInfo(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).serverInfo();
    return FoodbServerResponse(data: result.toJson());
  }

  Future<FoodbServerResponse> _view(FoodbServerRequest request) async {
    final result = await (await _getDb(request)).view(
      request.pathParams?['ddocId'],
      request.pathParams?['viewId'],
      GetViewRequest.fromJson({
        ...request.queryParams,
        ...(request.jsonBody ?? {}),
      }),
      (json) => json,
    );
    return FoodbServerResponse(data: result.toJson((v) => v));
  }
}
