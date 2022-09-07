import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:shelf/shelf.dart';

class FoodbRequest {
  String method;
  Uri url;
  String? body;
  String? messageId;
  FoodbRequest({
    required this.method,
    required this.url,
    this.messageId,
    this.body,
  });

  Map<String, dynamic>? get jsonBody {
    try {
      return jsonDecode(body ?? '');
    } catch (err) {
      return null;
    }
  }

  get queryParameters {
    return url.queryParameters;
  }

  get name {
    final paths = url.pathSegments;
    final pathLength = paths.length;
    if (method == 'GET') {
      if (pathLength == 0) {
        return 'serverInfo';
      } else if (pathLength == 1) {
        return 'info';
      } else if (pathLength == 2) {
        if (paths.contains('_bulk_get')) {
          return 'bulkGet';
        } else if (paths.contains('_revs_diff')) {
          return 'revsDiff';
        } else if (paths.contains('_all_docs')) {
          return 'getAllDocs';
        } else if (paths.contains('_find')) {
          return 'find';
        } else if (paths.contains('_changes')) {
          // TODO: changes not implemented
          return 'changesStream';
        } else {
          return 'get';
        }
      } else if (pathLength == 5 &&
          paths.contains('_design') &&
          paths.contains('_view')) {
        return 'getView';
      }
    } else if (method == 'POST') {
      if (paths.contains('_explain')) {
        return 'explain';
      } else if (paths.contains('_ensure_full_commit')) {
        return 'ensureFullCommit';
      } else if (paths.contains('_compact')) {
        return 'compact';
      } else if (paths.contains('_all_docs')) {
        return 'postAllDocs';
      } else if (paths.contains('_index')) {
        if (pathLength == 2) {
          return 'createIndex';
        }
      } else if (pathLength == 5 &&
          paths.contains('_design') &&
          paths.contains('_view')) {
        return 'postView';
      }
    } else if (method == 'PUT') {
      if ((paths.contains('_revs_limit') && pathLength == 2)) {
        return 'revsLimit';
      } else if (pathLength == 2) {
        return 'put';
      }
    } else if (method == 'DELETE') {
      if (pathLength == 1) {
        return 'destroy';
      } else if (pathLength == 2) {
        return 'delete';
      } else if (pathLength == 5 && paths.contains('_index')) {
        return 'deleteIndex';
      }
    } else if (method == 'HEAD') {
      if (pathLength == 1) {
        return 'initDb';
      }
    }
    throw Exception('unknown request');
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
    required String? body,
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

  Future<dynamic> handleRequest(FoodbRequest request) async {
    switch (request.name) {
      case 'get':
        return _get(request);
      case 'bulkGet':
        return _bulkGet(request);
      case 'getAllDocs':
        return _getAllDocs(request);
      case 'postAllDocs':
        return _postAllDocs(request);
      case 'changesStream':
        return _changesStream(request);
      case 'compact':
        return _compact(request);
      case 'createIndex':
        return _createIndex(request);
      case 'delete':
        return _delete(request);
      case 'deleteIndex':
        return _deleteIndex(request);
      case 'destroy':
        return _destroy(request);
      case 'ensureFullCommit':
        return _ensureFullCommit(request);
      case 'explain':
        return _explain(request);
      case 'find':
        return _find(request);
      case 'info':
        return _info(request);
      case 'initDb':
        return _initDb(request);
      case 'put':
        return _put(request);
      case 'revsDiff':
        return _revsDiff(request);
      case 'revsLimit':
        return _revsLimit(request);
      case 'serverInfo':
        return _serverInfo(request);
      case 'getView':
        return _getView(request);
      case 'postView':
        return _postView(request);
      default:
        throw Exception('invalid ${request.url.path}');
    }
  }

  // db.get
  Future<dynamic> _get(FoodbRequest request) async {
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
    final docId = request.url.pathSegments[1];
    final result = await db.delete(
      id: docId,
      rev: Rev.fromString(request.queryParameters['rev']),
    );
    return result.toJson();
  }

  // db.deleteIndex
  Future<dynamic> _deleteIndex(FoodbRequest request) async {
    final ddoc = request.url.pathSegments[2];
    final name = request.url.pathSegments.last;
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
    final url = request.url;
    final docId = url.pathSegments[1];
    final viewId = url.pathSegments.last;
    final result = await db.view(
      docId,
      viewId,
      GetViewRequest.fromJson(url.queryParameters),
      (json) => json,
    );
    return result.toJson((value) => value);
  }

  // db.postView
  Future<dynamic> _postView(FoodbRequest request) async {
    final url = request.url;
    final docId = url.pathSegments[1];
    final viewId = url.pathSegments.last;
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
