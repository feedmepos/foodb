import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:worker_manager/worker_manager.dart';

import 'package:foodb/foodb.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  await Executor().warmUp();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
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

class IsolateHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  IsolateHttpClient();

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    var request = RequestDto('GET', url.toString(), headers ?? {});
    return Executor().execute(arg1: request, fun1: _sendRequestInIsolate).next(
        onError: (error) async {
      throw Exception('Get failed $error');
    }, onValue: (value) {
      return value.toResponse(request.toRequest());
    });
  }

  @override
  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    var request = RequestDto('POST', url.toString(), headers ?? {},
        body: body.toString());
    return Executor().execute(arg1: request, fun1: _sendRequestInIsolate).next(
        onError: (error) async {
      throw Exception('Get failed $error');
    }, onValue: (value) {
      return value.toResponse(request.toRequest());
    });
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Foodb normalFoodb;
  late Foodb isolateFoodb;

  timed(String msg, Function fn) async {
    var stopwatch = Stopwatch();
    stopwatch.start();
    await fn();
    print(
        '${stopwatch.elapsedMilliseconds.toString().padLeft(8, '')} ms: done $msg');
  }

  @override
  void initState() {
    super.initState();
    normalFoodb = Foodb.couchdb(
        dbName: 'restaurant_5f3ba1803d4c3d001b29c18a',
        baseUri: Uri.parse('https://admin:secret@sync-dev.feedmeapi.com'));
    isolateFoodb = Foodb.couchdb(
        dbName: 'restaurant_5f3ba1803d4c3d001b29c18a',
        baseUri: Uri.parse(
          'https://admin:secret@sync-dev.feedmeapi.com',
        ),
        clientFactory: () {
          return IsolateHttpClient();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                CircularProgressIndicator(),
                ElevatedButton(
                    onPressed: () async {
                      await timed('test normal http', () async {
                        await normalFoodb.allDocs(
                            GetViewRequest(), (json) => null);
                      });
                    },
                    child: Text('test normal http')),
                ElevatedButton(
                    onPressed: () async {
                      await timed('test isolate http', () async {
                        await isolateFoodb.allDocs(
                            GetViewRequest(), (json) => null);
                      });
                    },
                    child: Text('test isolate http')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
