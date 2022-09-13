import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:foodb/foodb.dart';
import 'package:foodb_server/types.dart';

class FoodbServerConfig {
  String? username;
  String? password;
  SecurityContext? securityContext;
  FoodbServerConfig(
      {required this.username, required this.password, this.securityContext});
}

abstract class FoodbServer {
  final Foodb db;
  final FoodbServerConfig? config;
  FoodbServer({
    required this.db,
    required this.config,
  });

  Future<void> start() async {
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
    final username = config?.username;
    final password = config?.password;
    if (username != null || password != null) {
      String authorization =
          'Basic ${base64.encode(utf8.encode('$username:$password'))}';
      if (authorization != request.authorization) {
        return false;
      }
    }
    return true;
  }

  Future<FoodbServerResponse> handleRequest(FoodbServerRequest request) async {
    for (final route in routes) {
      final result = route.validate(request);
      if (result) {
        try {
          final valid = authorize(request);
          if (!valid) {
            return FoodbServerResponse(
              status: 401,
              data: {"error": 'unauthorized', "reason": 'unauthorized'},
            );
          }
          return await route.callback(request);
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

  // db.get
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
      final result = await db.get(
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

  // db.bulkGet
  Future<FoodbServerResponse> _bulkGet(FoodbServerRequest request) async {
    final result = await db.bulkGet(
      body: BulkGetRequest.fromJson(request.jsonBody ?? {}),
      revs: request.queryParams['revs'],
      fromJsonT: (v) => v,
    );
    return FoodbServerResponse(data: result.toJson((v) => v));
  }

  // db.allDocs
  Future<FoodbServerResponse> _allDocs(FoodbServerRequest request) async {
    final result = await db.allDocs(
      GetViewRequest.fromJson(
          {...request.queryParams, ...(request.jsonBody ?? {})}),
      (json) => json,
    );
    return FoodbServerResponse(data: result.toJson((v) => v));
  }

  // db.bulkDocs
  Future<FoodbServerResponse> _bulkDocs(FoodbServerRequest request) async {
    final result = await db.bulkDocs(
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

  // db.changesStream
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
    db.changesStream(
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

  // db.compact
  Future<FoodbServerResponse> _compact(FoodbServerRequest request) async {
    return FoodbServerResponse(data: (await db.compact()));
  }

  // db.createIndex
  Future<FoodbServerResponse> _createIndex(FoodbServerRequest request) async {
    final result = await db.createIndex(
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

  // db.delete
  Future<FoodbServerResponse> _delete(FoodbServerRequest request) async {
    final result = await db.delete(
      id: request.pathParams?['docId'],
      rev: Rev.fromString(request.queryParams['rev']),
    );
    return FoodbServerResponse(data: result.toJson());
  }

  // db.deleteIndex
  Future<FoodbServerResponse> _deleteIndex(FoodbServerRequest request) async {
    final result = await db.deleteIndex(
      ddoc: request.pathParams?['ddocId'],
      name: request.pathParams?['name'],
    );
    return FoodbServerResponse(data: result.toJson());
  }

  // db.destroy
  Future<FoodbServerResponse> _destroy(FoodbServerRequest request) async {
    return FoodbServerResponse(data: (await db.destroy()));
  }

  // db.ensureFullCommit
  Future<FoodbServerResponse> _ensureFullCommit(
      FoodbServerRequest request) async {
    final result = await db.ensureFullCommit();
    return FoodbServerResponse(data: result.toJson());
  }

  // db.explain
  Future<FoodbServerResponse> _explain(FoodbServerRequest request) async {
    final result =
        await db.explain(FindRequest.fromJson(request.jsonBody ?? {}));
    return FoodbServerResponse(data: result.toJson());
  }

  // db.find
  Future<FoodbServerResponse> _find(FoodbServerRequest request) async {
    final body = request.jsonBody ?? {};
    final result = await db.find(FindRequest.fromJson(body), (v) => v);
    return FoodbServerResponse(data: result.toJson((v) => v));
  }

  // db.info
  Future<FoodbServerResponse> _info(FoodbServerRequest request) async {
    final result = await db.info();
    return FoodbServerResponse(data: result.toJson());
  }

  // db.initDb
  Future<FoodbServerResponse> _initDb(FoodbServerRequest request) async {
    return FoodbServerResponse(data: (await db.initDb()));
  }

  // db.put
  Future<FoodbServerResponse> _put(
    FoodbServerRequest request, {
    String? prefix,
  }) async {
    String id = request.pathParams?['docId'] ?? '';
    if (prefix != null) {
      id = '$prefix/$id';
    }
    final result = await db.put(
      doc: Doc.fromJson({"_id": id, ...request.jsonBody ?? {}},
          (json) => json as Map<String, dynamic>),
      newEdits: request.queryParams['new_edits'],
    );
    return FoodbServerResponse(data: result.toJson());
  }

  // db.revsDiff
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
    final result = await db.revsDiff(body: body);
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

  // db.revsLimit
  Future<FoodbServerResponse> _revsLimit(FoodbServerRequest request) async {
    final result = await db.revsLimit(int.parse(request.body!));
    return FoodbServerResponse(data: {
      "ok": result,
    });
  }

  // db.serverInfo
  Future<FoodbServerResponse> _serverInfo(FoodbServerRequest request) async {
    final result = await db.serverInfo();
    return FoodbServerResponse(data: result.toJson());
  }

  // db.view
  Future<FoodbServerResponse> _view(FoodbServerRequest request) async {
    final result = await db.view(
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
