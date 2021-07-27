import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:uri/uri.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  getCouchDbAdapter() {
    return new CouchdbAdapter(dbName: dbName, baseUri: Uri.parse(baseUri));
  }

  test('URI BUILDER', () async {
    CouchdbAdapter couchdbAdapter = getCouchDbAdapter();
    UriBuilder uriBuilder = UriBuilder.fromUri(couchdbAdapter.getUri(''));
    uriBuilder.queryParameters = Map<String, String>();
    GetInfoResponse getInfoResponse = GetInfoResponse.fromJson(
        jsonDecode((await couchdbAdapter.client.get(uriBuilder.build())).body));
    expect(getInfoResponse.updateSeq, isNotNull);
  });
}
