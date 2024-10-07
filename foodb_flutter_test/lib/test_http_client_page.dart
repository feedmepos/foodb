import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:foodb_flutter_test/main.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:http/http.dart' as http;

import 'package:foodb/foodb.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class RequestDto {
  final String method;
  final String url;
  final Map<String, String> headers;
  final String body;

  RequestDto(this.method, this.url, this.headers, {this.body = ''});

  @override
  String toString() {
    return '[$method] url: $url\nheaders: $headers\n body: $body';
  }

  http.Request toRequest() {
    final request = http.Request(method, Uri.parse(url));
    if (method != "GET") {
      request.body = body;
    }
    request.headers.addAll(headers);
    return request;
  }
}

class ResponseDto {
  final List<int> bodyBytes;
  final int statusCode;
  final Map<String, String> headers;

  ResponseDto(this.bodyBytes, this.statusCode, {this.headers = const {}});

  @override
  String toString() {
    return 'statusCode : $statusCode\nheaders: $headers\n body: ${bodyBytes.length}';
  }

  http.Response toResponse(http.Request req) {
    return http.Response.bytes(
      bodyBytes,
      statusCode,
      headers: headers,
      request: req,
    );
  }
}

Future<ResponseDto> _sendRequestInIsolate(RequestDto dto) async {
  try {
    HttpOverrides.global = MyHttpOverrides();
    final request = dto.toRequest();
    final streamedResponse = await request.send();
    final httpResponse = await http.Response.fromStream(streamedResponse);
    final isolatedResponse = ResponseDto(
        httpResponse.bodyBytes, httpResponse.statusCode,
        headers: httpResponse.headers);
    return isolatedResponse;
  } catch (e) {
    rethrow;
  }
}

class TestHttpClientPage extends StatefulWidget {
  const TestHttpClientPage({Key? key}) : super(key: key);

  static String title = 'Test Http Client Page';

  @override
  State<TestHttpClientPage> createState() => _TestHttpClientPageState();
}

class _TestHttpClientPageState extends State<TestHttpClientPage> {
  late Foodb sourceFoodb;
  late Foodb targetFoodb;
  late Foodb replicateFoodb;
  late Store store;

  @override
  void initState() {
    super.initState();
    var isolate = Service.getIsolateID(Isolate.current);
    print("FOODB Running in isolate " + isolate.toString());
    sourceFoodb = Foodb.couchdb(
        dbName: 'find-production',
        baseUri: Uri.parse('http://admin:secret@192.168.0.176:5984'));
    store = GlobalStore.store;
    replicateFoodb = Foodb.keyvalue(
        dbName: 'replicate-test',
        keyValueDb: ObjectBoxAdapter(store));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TestHttpClientPage.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircularProgressIndicator(),
            Column(
              children: [
                ElevatedButton(
                    onPressed: () async {
                      await FoodbDebug.timed('reset db', () async {
                        targetFoodb.destroy();
                      });
                    },
                    child: Text('reset db')),
                ElevatedButton(
                    onPressed: () async {
                      await FoodbDebug.timed('start replication', () async {
                        replicate(
                          sourceFoodb,
                          replicateFoodb,
                          maxBatchSize: 300,
                          // continuous: true,
                        );
                      });
                    },
                    child: Text('start replication')),
                ElevatedButton(
                    onPressed: () async {
                      await FoodbDebug.timed('init target db', () async {
                        final firstSync = Completer();
                        setState(() {
                          targetFoodb = Foodb.keyvalue(
                              dbName: 'find-production',
                              keyValueDb: ObjectBoxAdapter(store)
                          );
                        });
                        await targetFoodb.initDb();
                        replicate(
                          sourceFoodb,
                          targetFoodb,
                          maxBatchSize: 300,
                          onComplete: firstSync.complete,
                        );
                        await firstSync.future;
                        await targetFoodb.createIndex(
                            index: QueryViewOptionsDef(
                                fields: ['type_bill', 'status']),
                            ddoc: 'type_bill_status',
                            name: 'bill_status');
                        var dd = await targetFoodb.fetchAllDesignDocs();
                        print(dd);
                        var dd2 = await targetFoodb.fetchAllDesignDocs();
                        print(dd2);
                      });
                    },
                    child: Text('init')),
                ElevatedButton(
                    onPressed: () async {
                      await FoodbDebug.timed('reset target db view', () async {
                        await targetFoodb.deleteIndex(
                            ddoc: 'type_bill_status', name: 'bill_status');
                        await targetFoodb.createIndex(
                            index: QueryViewOptionsDef(
                                fields: ['type_bill', 'status']),
                            ddoc: 'type_bill_status',
                            name: 'bill_status');
                        var dd = await targetFoodb.fetchAllDesignDocs();
                        print(dd);
                      });
                    },
                    child: Text('reset view')),
                ElevatedButton(
                    onPressed: () async {
                      await FoodbDebug.timed('first find', () async {
                        await targetFoodb.find(
                            FindRequest(
                                selector: AndOperator(operators: [
                              EqualOperator(key: 'type_bill', expected: true),
                              EqualOperator(key: 'status', expected: 'DRAFT'),
                            ])),
                            (json) => json);
                      });
                    },
                    child: Text('test find')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
