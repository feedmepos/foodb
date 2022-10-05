import 'dart:convert';
import 'dart:math';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  // final ctx = CouchdbTestContext();
  final ctx = InMemoryTestContext();
  // final ctx = HttpServerCouchdbTestContext();
  // final ctx = WebSocketServerCouchdbTestContext();
  changeStreamTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> changeStreamTest() {
  return [
    (FoodbTestContext ctx) {
      test('Test change stream: normal feed', () async {
        final db = await ctx.db('change-stream-normal-feed');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(2));
          expect(res.pending, 0);
        });
        var resultFn = expectAsync1((p0) => null, count: 2);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db.changesStream(ChangeRequest(feed: ChangeFeed.normal),
            onResult: resultFn, onComplete: completefn);
        await Future.delayed(Duration(milliseconds: 500),
            () async => db.bulkDocs(body: [Doc(id: 'c', model: {})]));
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: normal feed, with deleted', () async {
        final db = await ctx.db('change-stream-normal-feed');
        var doc = await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        var deleted = await db.delete(id: doc.id, rev: doc.rev);

        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(2));
          expect(res.results[0].deleted, isNull);
          expect(res.results[1].deleted, true);
          expect(res.results[1].doc, isNotNull);
          expect(res.results[1].doc!.rev, deleted.rev);
        });
        var resultFn = expectAsync1((p0) => null, count: 2);

        db.changesStream(
            ChangeRequest(feed: ChangeFeed.normal, includeDocs: true),
            onResult: resultFn,
            onComplete: completefn);
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: normal feed, limit 1', () async {
        final db = await ctx.db('change-stream-normal-feed-limit-1');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(1));
          expect(res.pending, 1);
        });
        var resultFn = expectAsync1((p0) => null, count: 1);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db.changesStream(ChangeRequest(feed: ChangeFeed.normal, limit: 1),
            onResult: resultFn, onComplete: completefn);
        await Future.delayed(Duration(milliseconds: 500),
            () async => db.bulkDocs(body: [Doc(id: 'c', model: {})]));
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: longpolling feed, since 0', () async {
        final db = await ctx.db('change-stream-long-polling-since-0');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(2));
          expect(res.pending, 0);
        });
        var resultFn = expectAsync1((p0) => null, count: 2);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db.changesStream(ChangeRequest(feed: ChangeFeed.longpoll),
            onResult: resultFn, onComplete: completefn);
        await Future.delayed(Duration(milliseconds: 500),
            () async => db.bulkDocs(body: [Doc(id: 'c', model: {})]));
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: longpolling feed, since 0, limit 1', () async {
        final db = await ctx.db('change-stream-long-polling-since-0-limit-1');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(1));
          expect(res.pending, 1);
        });
        var resultFn = expectAsync1((p0) => null, count: 1);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db.changesStream(ChangeRequest(feed: ChangeFeed.longpoll, limit: 1),
            onResult: resultFn, onComplete: completefn);
        await Future.delayed(Duration(milliseconds: 500),
            () async => db.bulkDocs(body: [Doc(id: 'c', model: {})]));
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: longpolling feed, since now', () async {
        final db = await ctx.db('change-stream-long-polling-since-now');
        var completefn = expectAsync1((ChangeResponse res) {
          expect(res.results, hasLength(1));
        });
        var resultFn = expectAsync1((p0) => {}, count: 1);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));
        db.changesStream(ChangeRequest(feed: ChangeFeed.longpoll, since: 'now'),
            onResult: resultFn, onComplete: completefn);
        await Future.delayed(Duration(milliseconds: 500),
            () async => db.bulkDocs(body: [Doc(id: 'c', model: {})]));
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: continuous feed', () async {
        final db = await ctx.db('change-stream-continuous-feed');
        var resultFn = expectAsync1((p0) => {}, count: 4);
        await db.put(doc: Doc(id: 'a', model: {}));
        await db.put(doc: Doc(id: 'b', model: {}));

        db.changesStream(ChangeRequest(feed: ChangeFeed.continuous),
            onResult: resultFn);
        await Future.delayed(
            Duration(milliseconds: 500),
            () async => db.bulkDocs(body: [
                  Doc(id: 'c', model: {}),
                  Doc(id: 'd', model: {}),
                ]));
      });
    },
    (FoodbTestContext ctx) {
      test('Test change stream: continuous feed, large document', () async {
        final db = await ctx.db('change-stream-continuous-feed');
        var resultFn = expectAsync1((p0) => {}, count: 4);
        await db.put(doc: Doc(id: 'a', model: {}));

        db.changesStream(
            ChangeRequest(feed: ChangeFeed.continuous, includeDocs: true),
            onResult: resultFn);
        await Future.delayed(Duration(milliseconds: 500), () async {
          await db.put(
            doc: Doc(
                id: 'b',
                model: List.generate(
                        300,
                        (index) => base64UrlEncode(List.generate(
                            5000, (index) => Random().nextInt(100))))
                    .asMap()
                    .map((key, value) => MapEntry(key.toString(), value))),
          );
          await db.put(
            doc: Doc(id: 'c', model: {}),
          );
          await db.put(
            doc: Doc(
                id: 'd',
                model: List.generate(
                        300,
                        (index) => base64UrlEncode(List.generate(
                            5000, (index) => Random().nextInt(100))))
                    .asMap()
                    .map((key, value) => MapEntry(key.toString(), value))),
          );
        });
      });
    },
  ];
}
