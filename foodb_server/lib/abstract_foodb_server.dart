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
      GetViewRequest.fromJson(
          {...request.queryParams, ...(request.jsonBody ?? {})}),
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
