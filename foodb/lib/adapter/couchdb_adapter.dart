import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/open_revs.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:http/http.dart';
import 'package:foodb/adapter/params_converter.dart';
import 'package:uri/uri.dart';

class CouchdbAdapter extends AbstractAdapter {
  late Client client;
  Uri baseUri;

  CouchdbAdapter({required String dbName, required this.baseUri})
      : super(dbName: dbName) {
    try {
      this.client = getClient();
      if (!this.baseUri.scheme.toLowerCase().startsWith('http')) {
        throw new Exception('URI scheme must be http/https');
      }
    } catch (err) {
      throw new AdapterException(
          error: 'Invalid uri format', reason: err.toString());
    }
  }

  Client getClient() {
    return Client();
  }

  Uri getUri(String path) {
    return Uri.parse("${baseUri.toString()}/$dbName/$path");
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = false}) async {
    var response = jsonDecode((await this.client.post(this.getUri('_bulk_docs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'new_edits': newEdits,
              'docs': body.map((e) {
                Map<String, dynamic> map = e.toJson((value) => value);
                map.removeWhere((key, value) => value == null);
                return map;
              }).toList()
            })))
        .body);

    List<PutResponse> putResponses = [];

    if (response is Map<String, dynamic>) {
      return BulkDocResponse.fromJson(response);
    } else if (response.length > 0) {
      for (Map<String, dynamic> row in response) {
        putResponses.add(PutResponse.fromJson(row));
      }
      return BulkDocResponse(putResponses: putResponses);
    }
    return BulkDocResponse();
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    var client = getClient();
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_changes')));
    uriBuilder.queryParameters = convertToParams(request.toJson());

    var res = await client.send(Request('get', uriBuilder.build()));
    var streamedRes = res.stream.transform(utf8.decoder);
    var streamedResponse = ChangesStream(
        stream: streamedRes,
        onCancel: () {
          client.close();
        },
        feed: request.feed);
    return streamedResponse;
  }

  @override
  Future<EnsureFullCommitResponse> ensureFullCommit() async {
    return EnsureFullCommitResponse.fromJson(jsonDecode((await this.client.post(
            this.getUri('_ensure_full_commit'),
            headers: {'Content-Type': 'application/json'}))
        .body));
  }

  @override
  Future<Doc<T>?> get<T>(
      {required String id,
      bool attachments = false,
      bool attEncodingInfo = false,
      List<String>? attsSince,
      bool conflicts = false,
      bool deletedConflicts = false,
      bool latest = false,
      bool localSeq = false,
      bool meta = false,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri(id)));
    uriBuilder.queryParameters = convertToParams({
      'revs': revs,
      'conflicts': conflicts,
      'deleted_conflicts': deletedConflicts,
      'latest': latest,
      'local_seq': localSeq,
      'meta': meta,
      'att_encoding_info': attEncodingInfo,
      'attachments': attachments,
      'atts_since': attsSince,
      'rev': rev,
      'revs_info': revsInfo
    });

    var response = (await this.client.get(uriBuilder.build())).body;
    Map<String, dynamic> result = jsonDecode(response);

    return result.containsKey('_id')
        ? Doc<T>.fromJson(
            result, (json) => fromJsonT(json as Map<String, dynamic>))
        : null;
  }

  @override
  Future<GetInfoResponse> info() async {
    return GetInfoResponse.fromJson(
        jsonDecode((await this.client.get(this.getUri(''))).body));
  }

  String generateNewRev(String? oldRev) {
    var r = Random(DateTime.now().millisecond);
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    String tail =
        List.generate(33, (index) => _chars[r.nextInt(_chars.length)]).join();

    if (oldRev == null) {
      return '0-$tail';
    }
    return '${int.parse(oldRev.split('-')[0]) + 1}-$tail';
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc,
      bool newEdits = true,
      String? newRev}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(doc.id));
    uriBuilder.queryParameters = convertToParams(
        {'new_edits': newEdits, 'rev': newEdits ? doc.rev : newRev});

    Map<String, dynamic> newBody = doc.model;

    if (!newEdits) {
      if (newRev == null) {
        throw new AdapterException(
            error: 'newRev is required when newEdits is false');
      }
      newBody['_revisions'] = {
        "ids": doc.rev == null
            ? [newRev.split('-')[1]]
            : [newRev.split('-')[1], doc.rev!.split('-')[1]],
        "start": int.parse(newRev.split('-')[0])
      };
    }
    return PutResponse.fromJson(jsonDecode(
        (await this.client.put(uriBuilder.build(), body: jsonEncode(newBody)))
            .body));
  }

  @override
  Future<DeleteResponse> delete(
      {required String id, required String rev}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(id));
    uriBuilder.queryParameters = convertToParams({'rev': rev});
    return DeleteResponse.fromJson(
        jsonDecode((await this.client.delete(uriBuilder.build())).body));
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<String>> body}) async {
    Response response = await this.client.post(this.getUri("_revs_diff"),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    return (jsonDecode(response.body).map<String, RevsDiff>((k, v) {
      return MapEntry<String, RevsDiff>(k, RevsDiff.fromJson(v));
    }));
  }

  @override
  Future<GetAllDocs<T>> allDocs<T>(GetAllDocsRequest getAllDocsRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_all_docs')));
    uriBuilder.queryParameters = convertToParams(getAllDocsRequest.toJson());
    return GetAllDocs<T>.fromJson(
        jsonDecode((await this.client.get(uriBuilder.build())).body),
        (a) => fromJsonT(a as Map<String, dynamic>));
  }

  @override
  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      Map<String, Object>? partialFilterSelector}) async {
    Map<String, dynamic> body = {
      'index': {'fields': indexFields},
      'type': type
    };
    if (ddoc != null) {
      body.putIfAbsent('ddoc', () => ddoc);
    }
    if (name != null) {
      body.putIfAbsent('name', () => name);
    }
    if (partialFilterSelector != null) {
      body.putIfAbsent('partial_filter_selector', () => partialFilterSelector);
    }
    var response = (jsonDecode((await this.client.post(this.getUri('_index'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)))
        .body));

    return IndexResponse.fromJson(response);
  }

  @override
  Future<FindResponse<T>> find<T>(FindRequest findRequest,
      T Function(Map<String, dynamic>) fromJsonT) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    var response = jsonDecode((await this.client.post(this.getUri('_find'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)))
        .body);

    return FindResponse.fromJson(
        response, (e) => fromJsonT(e as Map<String, dynamic>));
  }

  @override
  Future<ExplainResponse> explain(FindRequest findRequest) async {
    Map<String, dynamic> body = findRequest.toJson();
    body.removeWhere((key, value) => value == null);
    var response = jsonDecode((await this.client.post(this.getUri('_explain'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body)))
        .body);
    print(response);
    return ExplainResponse.fromJson(response);
  }

  @override
  Future<bool> init() async {
    Response response = await this.client.head(this.getUri(""));
    if (response.statusCode == 404) {
      Response createResponse = await this.client.put(this.getUri(""));
    }

    return true;
  }

  @override
  Future<bool> destroy() async {
    await this.client.delete(this.getUri(''));
    return true;
  }

  @override
  Future<List<Doc<T>>> getWithOpenRev<T>(
      {required String id,
      bool attachments = false,
      bool attEncodingInfo = false,
      List<String>? attsSince,
      bool conflicts = false,
      bool deletedConflicts = false,
      bool latest = false,
      bool localSeq = false,
      bool meta = false,
      required OpenRevs openRevs,
      String? rev,
      bool revs = false,
      bool revsInfo = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri(id)));
    uriBuilder.queryParameters = convertToParams({
      'revs': revs,
      'conflicts': conflicts,
      'deleted_conflicts': deletedConflicts,
      'latest': latest,
      'local_seq': localSeq,
      'meta': meta,
      'att_encoding_info': attEncodingInfo,
      'attachments': attachments,
      'atts_since': attsSince,
      'rev': rev,
      'open_revs': openRevs.getOpenRevs(),
      'revs_info': revsInfo
    });
    var response = (await this
            .client
            .get(uriBuilder.build(), headers: {'Accept': 'application/json'}))
        .body;
    List<Doc<T>> results = jsonDecode(response)
        .where((value) => value.containsKey("ok") == true)
        .map<Doc<T>>((value) => Doc<T>.fromJson(
            value["ok"], (json) => fromJsonT(json as Map<String, dynamic>)))
        .toList();
    return results;
  }
}
