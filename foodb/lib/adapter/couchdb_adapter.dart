import 'dart:async';
import 'dart:convert';
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/view.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/server.dart';
import 'package:foodb/adapter/methods/open_revs.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:http/http.dart';
import 'package:foodb/adapter/params_converter.dart';
import 'package:uri/uri.dart';

class CouchdbAdapter extends Foodb {
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
    return new Client();
  }

  Uri getUri(String path) {
    return Uri.parse("${baseUri.toString()}/$dbName/$path");
  }

  String get dbUri {
    return this.getUri("").toString();
  }

  @override
  Future<BulkGetResponse<T>> bulkGet<T>(
      {required BulkGetRequest body,
      bool revs = false,
      required T Function(Map<String, dynamic> json) fromJsonT}) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_bulk_get')));
    uriBuilder.queryParameters = convertToParams({"revs": revs});
    var b = body.toJson();
    var response = (await this.client.post(uriBuilder.build(),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode(body.toJson())));
    if (response.statusCode == 200) {
      // var list = jsonDecode(response.body)["results"];
      return BulkGetResponse<T>.fromJson(jsonDecode(response.body),
          (json) => fromJsonT(json as Map<String, dynamic>));
      // .fromIterable(list,
      //     key: (idDoc) => idDoc["id"],
      //     value: (idDoc) => idDoc["docs"]
      //         .where((item) => item.containsKey("ok") == true)
      //         .map<Doc<T>>((doc) => Doc<T>.fromJson(
      //             doc["ok"], (json) => fromJsonT(json as Map<String, dynamic>)))
      //         .toList());
    }
    throw AdapterException(error: "Invalid Status Code");
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = true}) async {
    var response = (await this.client.post(this.getUri('_bulk_docs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'new_edits': newEdits,
          'docs': body.map((e) {
            Map<String, dynamic> map = e.toJson((value) => value);
            map.removeWhere((key, value) => value == null);
            return map;
          }).toList()
        })));

    if (response.statusCode == 201) {
      List<dynamic> responses = jsonDecode(response.body);
      List<PutResponse> putResponses = [];
      for (Map<String, dynamic> row in responses) {
        putResponses.add(PutResponse.fromJson(row));
      }
      return BulkDocResponse(putResponses: putResponses);
    } else {
      throw AdapterException(
          error: 'Invalid status code', reason: response.statusCode.toString());
    }
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    var changeClient = getClient();
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_changes')));
    uriBuilder.queryParameters = convertToParams(request.toJson());
    var res = await changeClient.send(Request('get', uriBuilder.build()));
    var streamedRes = res.stream.transform(utf8.decoder);
    var streamedResponse = ChangesStream(
        stream: streamedRes,
        onCancel: () {
          changeClient.close();
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
  Future<GetViewResponse<T>> allDocs<T>(GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    UriBuilder uriBuilder = UriBuilder.fromUri((this.getUri('_all_docs')));
    uriBuilder.queryParameters = convertToParams(getViewRequest.toJson());
    
    var body = (await this.client.get(uriBuilder.build())).body;
    return GetViewResponse<T>.fromJson(
        jsonDecode(body), (a) => fromJsonT(a as Map<String, dynamic>));
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
    var response = await this.client.get(this.getUri(''));
    if (response.statusCode != 200) {
      throw AdapterException(error: 'database not found');
    }
    return GetInfoResponse.fromJson(jsonDecode(response.body));
  }

  @override
  Future<GetServerInfoResponse> serverInfo() async {
    return GetServerInfoResponse.fromJson(
        jsonDecode((await this.client.get(this.baseUri)).body));
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(doc.id));
    Map<String, dynamic> param = {'new_edits': newEdits};
    if (doc.rev != null) param['rev'] = doc.rev!.toString();
    uriBuilder.queryParameters = convertToParams(param);

    Map<String, dynamic> newBody = doc.toJson((value) => value);

    if (!newEdits) {
      if (doc.rev == null) {
        throw new AdapterException(
            error: 'rev is required when newEdits is false');
      }
      if (doc.revisions != null) {
        newBody['_revisions'] = doc.revisions!.toJson();
      }
    }
    var responseBody = jsonDecode(
        (await this.client.put(uriBuilder.build(), body: jsonEncode(newBody)))
            .body);

    if (responseBody['error'] != null) {
      throw AdapterException(
          error: responseBody['error'], reason: responseBody['reason']);
    }
    return PutResponse.fromJson(responseBody);
  }

  @override
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    UriBuilder uriBuilder = new UriBuilder.fromUri(this.getUri(id));
    uriBuilder.queryParameters = convertToParams({'rev': rev.toString()});
    var result =
        jsonDecode((await this.client.delete(uriBuilder.build())).body);
    if (result['error'] != null) {
      throw AdapterException(error: result['error'], reason: result['reason']);
    }
    return DeleteResponse.fromJson(result);
  }

  @override
  Future<Map<String, RevsDiff>> revsDiff(
      {required Map<String, List<Rev>> body}) async {
    Response response = await this.client.post(this.getUri("_revs_diff"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body.map((key, value) =>
            MapEntry(key, value.map((e) => e.toString()).toList()))));
    Map<String, dynamic> decoded = jsonDecode(response.body);
    if (decoded.isEmpty) {
      return {};
    }
    return decoded.map<String, RevsDiff>((k, v) {
      return MapEntry<String, RevsDiff>(k, RevsDiff.fromJson(v));
    });
  }

  @override
  Future<IndexResponse> createIndex(
      {required List<String> indexFields,
      String? ddoc,
      String? name,
      String type = 'json',
      bool? partitioned}) async {
    Map<String, dynamic> body = Map();
    body['type'] = type;
    body['index'] = Map<String, dynamic>();
    body['index']['fields'] = indexFields;
    if (partitioned != null) {
      body['partitioned'] = partitioned;
    }
    if (ddoc != null) {
      body['ddoc'] = ddoc;
    }
    if (name != null) {
      body['name'] = name;
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
    return ExplainResponse.fromJson(response);
  }

  @override
  Future<bool> initDb() async {
    final response = await this.client.head(this.getUri(""));
    if (response.statusCode == 404) {
      final response = await this.client.put(this.getUri(""));
      final body = jsonDecode(response.body);
      if (body['error'] != null) {
        throw new AdapterException(
            error: body['error'], reason: body['reason']);
      }
      return true;
    } else {
      return true;
    }
  }

  @override
  Future<bool> destroy() async {
    await this.client.delete(this.getUri(''));
    return true;
  }

  @override
  Future<GetViewResponse<T>> view<T>(
      String ddocId,
      String viewName,
      GetViewRequest getViewRequest,
      T Function(Map<String, dynamic> json) fromJsonT) async {
    UriBuilder uriBuilder =
        UriBuilder.fromUri((this.getUri('_design/$ddocId/_view/$viewName')));
    var json = getViewRequest.toJson();
    uriBuilder.queryParameters = convertToParams(json);
    var path = uriBuilder.build().toString();
    var jreon = jsonDecode((await this.client.get(uriBuilder.build())).body);
    var sda = GetViewResponse<T>.fromJson(
        jsonDecode((await this.client.get(uriBuilder.build())).body),
        (a) => fromJsonT(a as Map<String, dynamic>));
    return GetViewResponse<T>.fromJson(
        jsonDecode((await this.client.get(uriBuilder.build())).body),
        (a) => fromJsonT(a as Map<String, dynamic>));
  }
}
