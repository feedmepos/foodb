// Regression tests for a dropped change in the CouchDB continuous changes stream.
//
// Bug: `changesStream` with a continuous feed parsed the lines found in its
// cache, and after any successful parse it did `cache = ''`. A network read can
// end in the middle of a line. When one read held whole lines followed by the
// first part of the next line, that first part was deleted with the cache. The
// rest of the line then arrived without its start, never matched `{"`, and the
// change was never delivered. The replication checkpoint moved past it.
//
// The fix: parse only lines that end in '\n' and keep the trailing part in the
// cache until its line is complete.
//
// All tests use a mock HTTP client. No CouchDB or Docker is needed.

import 'dart:async';
import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Replies to `_changes` with [_pieces] as separate stream events, one per piece.
class _PiecesClient extends http.BaseClient {
  final List<String> _pieces;

  _PiecesClient(this._pieces);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('_changes')) {
      final controller = StreamController<List<int>>();
      Future.microtask(() async {
        for (final piece in _pieces) {
          controller.add(utf8.encode(piece));
          // yield so the listener handles each piece as its own event
          await Future.delayed(Duration.zero);
        }
        await controller.close();
      });
      return http.StreamedResponse(controller.stream, 200);
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{"ok":true}')), 200);
  }
}

String _line(int i) => '${jsonEncode({
          'seq': '$i-g1AAAAB$i',
          'id': 'doc-$i',
          'changes': [
            {'rev': '1-abc$i'}
          ],
        })}\n';

/// Cuts [text] into pieces of at most [size] characters.
List<String> _cut(String text, int size) => [
      for (var i = 0; i < text.length; i += size)
        text.substring(i, i + size > text.length ? text.length : i + size)
    ];

/// Runs the continuous feed against [pieces] and returns the delivered ids.
Future<List<String>> _deliveredIds(List<String> pieces,
    {int expected = 0}) async {
  final db = Foodb.couchdb(
    dbName: 'partial-line-test',
    baseUri: Uri.parse('http://localhost:5984'),
    clientFactory: () => _PiecesClient(pieces),
  );
  final ids = <String>[];
  final done = Completer<void>();
  final stream = await db.changesStream(
    ChangeRequest(feed: ChangeFeed.continuous, since: '0', heartbeat: 0),
    onResult: (r) {
      ids.add(r.id);
      if (expected > 0 && ids.length >= expected && !done.isCompleted) {
        done.complete();
      }
    },
    onError: (e, s) {
      if (!done.isCompleted) done.completeError(e ?? 'changes stream error', s);
    },
  );
  // The mock stream ends after the last piece, so give the listener time to
  // handle it. Wait for the expected count, or a short time when none is set.
  await Future.any([
    done.future,
    Future.delayed(const Duration(milliseconds: 500)),
  ]);
  await stream.cancel();
  return ids;
}

void main() {
  const total = 40;
  final body = [for (var i = 1; i <= total; i++) _line(i)].join();
  final expectedIds = [for (var i = 1; i <= total; i++) 'doc-$i'];

  test('control: whole lines in every event are all delivered', () async {
    final ids = await _deliveredIds([for (var i = 1; i <= total; i++) _line(i)],
        expected: total);
    expect(ids, equals(expectedIds));
  });

  test('a read that ends mid-line after whole lines does not drop the change',
      () async {
    // Two whole lines and the first half of the third line, then the rest.
    final third = _line(3);
    final half = third.length ~/ 2;
    final ids = await _deliveredIds([
      _line(1) + _line(2) + third.substring(0, half),
      third.substring(half) + _line(4),
    ], expected: 4);
    expect(ids, equals(['doc-1', 'doc-2', 'doc-3', 'doc-4']));
  });

  for (final size in [1, 2, 7, 61, 100, 200, 243, 244, 245, 700, 1448]) {
    test('feed cut every $size characters delivers every change once, in order',
        () async {
      final ids = await _deliveredIds(_cut(body, size), expected: total);
      expect(ids, equals(expectedIds));
    });
  }

  test('a last line whose newline has not arrived yet is delivered at once',
      () async {
    // The final piece is a whole JSON object with no trailing newline.
    final withoutNewline = _line(2).trimRight();
    final ids = await _deliveredIds([_line(1), withoutNewline], expected: 2);
    expect(ids, equals(['doc-1', 'doc-2']));
  });

  test('a heartbeat newline between two parts of a line keeps the line intact',
      () async {
    // CouchDB writes a heartbeat as a bare newline only between lines, but the
    // parser must not lose the cached part when a whitespace-only event comes.
    final second = _line(2);
    final half = second.length ~/ 2;
    final ids = await _deliveredIds([
      _line(1) + second.substring(0, half),
      '\n',
      second.substring(half),
    ], expected: 2);
    expect(ids, equals(['doc-1', 'doc-2']));
  });
}
