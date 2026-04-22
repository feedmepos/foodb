// Regression tests for the trim bug in CouchDB continuous changes stream.
//
// Bug: `changesStream` with continuous feed did `cache += event.trim()`.
// When a large document's JSON is split across multiple HTTP stream chunks,
// any chunk whose first character is a space (i.e. the previous chunk ended
// mid-word inside a JSON string value) had its leading space stripped,
// corrupting the decoded string field values.
//
// The CouchDB heartbeat is a bare `\n` which must still be treated as "empty".
// The fix: append the raw event (not trimmed) when non-empty, so that spaces
// inside JSON string values are preserved across chunk boundaries.
//
// Tests:
//   1. [unit] Mock HTTP client — splits the JSON into 2 chunks at a midpoint
//      space inside a string value. Deterministic, no Docker needed.
//   2. [integration] Real CouchDB via Docker.
//      Requires: docker run -d --name couchdb-test \
//                  -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=password \
//                  -p 5984:5984 couchdb:3

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:foodb/foodb.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Model & assertions shared by both tests.
// ---------------------------------------------------------------------------

// Build a model whose field values all contain spaces. 300 fields × 200 words
// makes the JSON ~450 KB, well above any TCP chunk size.
Map<String, dynamic> _buildLargeModel() {
  const wordCount = 200;
  final valueWithSpaces = List.generate(wordCount, (i) => 'word$i').join(' ');
  return Map<String, dynamic>.fromEntries(
    List.generate(
        300, (i) => MapEntry<String, dynamic>('field$i', '$valueWithSpaces v$i')),
  );
}

void _assertAllFields(Map<String, dynamic>? actual) {
  expect(actual, isNotNull, reason: 'doc must be present in the change result');
  const wordCount = 200;
  final expected = List.generate(wordCount, (i) => 'word$i').join(' ');
  for (int i = 0; i < 300; i++) {
    expect(
      actual!['field$i'],
      equals('$expected v$i'),
      reason: 'field$i must retain all spaces — '
          'trim bug strips the leading space when a chunk boundary falls inside a string value',
    );
  }
}

// ---------------------------------------------------------------------------
// Mock HTTP client for the unit test.
//
// Strategy: find the first space at or after the midpoint of the JSON string
// and split there. The second chunk therefore starts with a space character
// that is in the middle of a JSON string value — exactly the condition that
// triggers the trim bug. Only 2 chunks / 2 stream events, so the test is fast.
// ---------------------------------------------------------------------------
class _TwoChunkClient extends http.BaseClient {
  final String _responseBody;

  _TwoChunkClient(this._responseBody);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('_changes')) {
      final mid = _responseBody.length ~/ 2;
      final splitPos = _responseBody.indexOf(' ', mid);
      assert(splitPos != -1, 'No space found after midpoint — increase model size');

      // chunk1 ends before the space; chunk2 starts WITH the space.
      final chunk1 = _responseBody.substring(0, splitPos);
      final chunk2 = _responseBody.substring(splitPos); // leading space here

      final controller = StreamController<List<int>>();
      Future.microtask(() async {
        controller.add(utf8.encode(chunk1));
        await Future.delayed(Duration.zero); // yield so the listener sees chunk1 first
        controller.add(utf8.encode(chunk2));
        await Future.delayed(Duration.zero);
        await controller.close();
      });
      return http.StreamedResponse(controller.stream, 200);
    }
    // Stub OK for any other requests (e.g. during initDb).
    return http.StreamedResponse(
        Stream.value(utf8.encode('{"ok":true}')), 200);
  }
}

// Build a synthetic CouchDB continuous-feed change event line.
String _buildChangeJson(Map<String, dynamic> model) {
  final event = <String, dynamic>{
    'seq': '1-g1AAAAB',
    'id': 'large-doc-spaces',
    'changes': [
      {'rev': '1-abc123'}
    ],
    'doc': {
      '_id': 'large-doc-spaces',
      '_rev': '1-abc123',
      ...model,
    },
  };
  // CouchDB continuous feed format: one JSON object per line.
  return '${jsonEncode(event)}\n';
}

// ---------------------------------------------------------------------------
// Helpers for the integration test.
// ---------------------------------------------------------------------------
const _couchdbUri = 'http://admin:password@localhost:5984';

Future<Foodb> _getDb(String name) async {
  HttpOverrides.global = _TrustAllCerts();
  final db = Foodb.couchdb(
    dbName: 'test-$name',
    baseUri: Uri.parse(_couchdbUri),
  );
  try {
    await db.info();
    await db.destroy();
  } catch (_) {}
  await db.initDb();
  addTearDown(() => db.destroy());
  return db;
}

class _TrustAllCerts extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // -------------------------------------------------------------------------
  // Unit test — no CouchDB needed.
  // The mock delivers the JSON in 2 chunks; the second chunk starts with a
  // space that is inside a string value.
  //   Before fix: event.trim() strips that leading space → corrupted value →
  //               assertion error.
  //   After fix:  raw event appended → space preserved → assertion passes.
  // -------------------------------------------------------------------------
  test(
      '[unit] continuous changes stream: chunk-boundary space inside string value is preserved',
      () async {
    final largeModel = _buildLargeModel();
    final changeJson = _buildChangeJson(largeModel);

    final mockClient = _TwoChunkClient(changeJson);

    final db = Foodb.couchdb(
      dbName: 'test-trim-bug',
      baseUri: Uri.parse('http://localhost:5984'),
      clientFactory: () => mockClient,
    );

    final completer = Completer<ChangeResult>();

    db.changesStream(
      ChangeRequest(feed: ChangeFeed.continuous, includeDocs: true),
      onResult: (result) {
        if (result.id == 'large-doc-spaces' && !completer.isCompleted) {
          completer.complete(result);
        }
      },
    );

    final result =
        await completer.future.timeout(const Duration(seconds: 10));

    _assertAllFields(result.doc?.model);
  });

  // -------------------------------------------------------------------------
  // Integration test — requires Docker CouchDB.
  // Large document (~450 KB JSON) is written to CouchDB and received via the
  // continuous changes stream. CouchDB may split it across TCP chunks.
  // -------------------------------------------------------------------------
  test(
      '[integration] continuous changes stream: spaces preserved in large document against CouchDB',
      () async {
    final db = await _getDb('changes-trim-bug');
    final largeModel = _buildLargeModel();

    final completer = Completer<ChangeResult>();

    final stream = db.changesStream(
      ChangeRequest(
          feed: ChangeFeed.continuous, includeDocs: true, since: 'now'),
      onResult: (result) {
        if (result.id == 'large-doc-spaces' && !completer.isCompleted) {
          completer.complete(result);
        }
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));
    await db.put(doc: Doc(id: 'large-doc-spaces', model: largeModel));

    final result =
        await completer.future.timeout(const Duration(seconds: 15));
    await stream.cancel();

    _assertAllFields(result.doc?.model);
  });
}
