import 'dart:async';
import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:foodb_server/types.dart';

abstract class FoodbServer {
  final Foodb db;
  FoodbServer(this.db);

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
      FoodbRoute.put(path: '/<dbId>/<docId>', callback: _put),
      FoodbRoute.get(path: '/<dbId>/<docId>', callback: _get),
    ]);
  }

  Future<void> stop();

  List<FoodbRoute> routes = [];

  void setRoutes(List<FoodbRoute> newRoutes) {
    routes = [...newRoutes];
  }

  Future<FoodbServerResponse> handleRequest(FoodbServerRequest request) async {
    for (final route in routes) {
      final result = route.validate(request);
      if (result) {
        return await route.callback(request);
      }
    }
    throw Exception('unknown request');
  }

  // db.get
  Future<FoodbServerResponse> _get(FoodbServerRequest request) async {
    Map<String, dynamic> queryParams = request.queryParams;
    try {
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
      return FoodbServerResponse(data: result?.toJson((v) => v));
    } catch (err) {
      return FoodbServerResponse(data: null);
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
    Timer? timer;
    if (changesRequest.feed == ChangeFeed.continuous) {
      timer = Timer(Duration(milliseconds: changesRequest.heartbeat), () {
        streamController.close();
      });
    }
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
          timer?.cancel();
          timer = Timer(Duration(milliseconds: changesRequest.heartbeat), () {
            streamController.close();
          });
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
  Future<FoodbServerResponse> _put(FoodbServerRequest request) async {
    final result = await db.put(
      doc: Doc.fromJson(
          request.jsonBody ?? {}, (json) => json as Map<String, dynamic>),
      newEdits: request.queryParams['new_edits'],
    );
    return FoodbServerResponse(data: result.toJson());
  }

  // db.revsDiff
  Future<FoodbServerResponse> _revsDiff(FoodbServerRequest request) async {
    final body = request.jsonBody?.entries.fold<Map<String, List<Rev>>>({},
            (result, entry) {
          result[entry.key] =
              entry.value.map((rev) => Rev.fromString(rev)).toList();
          return result;
        }) ??
        {};
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
