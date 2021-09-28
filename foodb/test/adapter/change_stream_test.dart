import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'adapter_test.dart';

void main() {
  // final ctx = CouchdbAdapterTestContext();
  final ctx = InMemoryAdapterTestContext();
  changeStreamTest().forEach((t) {
    t(ctx);
  });
}

List<Function(AdapterTestContext)> changeStreamTest() {
  return [
    (AdapterTestContext ctx) {
      test('Test change stream: normal feed', () async {
        final db = await ctx.db('test-change-stream-normal-feed');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(2));
          expect(res.pending, 0);
        });
        var resultFn = expectAsync1((p0) => null, count: 2);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db
            .changesStream(ChangeRequest(feed: ChangeFeed.normal))
            .then((stream) async {
          stream.listen(onResult: resultFn, onComplete: completefn);
          await db.put(doc: Doc(id: 'c', model: {}));
        });
      });
    },
    (AdapterTestContext ctx) {
      test('Test change stream: normal feed, limit 1', () async {
        final db = await ctx.db('test-change-stream-normal-feed-limit-1');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(1));
          expect(res.pending, 1);
        });
        var resultFn = expectAsync1((p0) => null, count: 1);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db
            .changesStream(ChangeRequest(feed: ChangeFeed.normal, limit: 1))
            .then((stream) async {
          stream.listen(onResult: resultFn, onComplete: completefn);
          await db.put(doc: Doc(id: 'c', model: {}));
        });
      });
    },
    (AdapterTestContext ctx) {
      test('Test change stream: longpolling feed, since 0', () async {
        final db = await ctx.db('test-change-stream-long-polling-since-0');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(2));
          expect(res.pending, 0);
        });
        var resultFn = expectAsync1((p0) => null, count: 2);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db
            .changesStream(ChangeRequest(feed: ChangeFeed.longpoll))
            .then((stream) async {
          stream.listen(onResult: resultFn, onComplete: completefn);
          await db.put(doc: Doc(id: 'c', model: {}));
        });
      });
    },
    (AdapterTestContext ctx) {
      test('Test change stream: longpolling feed, since 0, limit 1', () async {
        final db =
            await ctx.db('test-change-stream-long-polling-since-0-limit-1');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(1));
          expect(res.pending, 1);
        });
        var resultFn = expectAsync1((p0) => null, count: 1);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db
            .changesStream(ChangeRequest(feed: ChangeFeed.longpoll, limit: 1))
            .then((stream) async {
          stream.listen(onResult: resultFn, onComplete: completefn);
          await db.put(doc: Doc(id: 'c', model: {}));
        });
      });
    },
    (AdapterTestContext ctx) {
      test('Test change stream: longpolling feed, since now', () async {
        final db = await ctx.db('test-change-stream-long-polling-since-now');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(1));
        });
        var resultFn = expectAsync1((p0) => null, count: 1);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db
            .changesStream(
                ChangeRequest(feed: ChangeFeed.longpoll, since: 'now'))
            .then((stream) async {
          stream.listen(onResult: resultFn, onComplete: completefn);
          await db.bulkDocs(
              body: [Doc(id: 'c', model: {}), Doc(id: 'd', model: {})]);
        });
      });
    },
    (AdapterTestContext ctx) {
      test('Test change stream: continuous feed', () async {
        final db = await ctx.db('test-change-stream-continuous-feed');
        var resultFn = expectAsync1((p0) => {print(p0)}, count: 4);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db
            .changesStream(ChangeRequest(feed: ChangeFeed.continuous))
            .then((stream) async {
          stream.listen(onResult: resultFn);
          await db.bulkDocs(body: [
            Doc(id: 'c', model: {}),
            Doc(id: 'd', model: {}),
          ]);
        });
      });
    }
  ];
}
