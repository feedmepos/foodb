import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';

import 'helper.dart';

void main() async {
  testEachAdapter('test-normal-feed', (ctx) {
    test('Test change stream: normal feed', () async {
      final db = ctx.db!;
      var completefn = expectAsync1((ChangeResponse res) {
        expect(res.results, hasLength(2));
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
  });

  testEachAdapter('test-longpoll-feed-since-0', (ctx) {
    test('Test change stream: longpolling feed, since 0', () async {
      final db = ctx.db!;
      var completefn = expectAsync1((ChangeResponse res) {
        expect(res.results, hasLength(2));
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
  });

  testEachAdapter('test-longpoll-feed-since-now', (ctx) {
    test('Test change stream: longpolling feed, since now', () async {
      final db = ctx.db!;
      var completefn = expectAsync1((ChangeResponse res) {
        expect(res.results, hasLength(1));
      });
      var resultFn = expectAsync1((p0) => null, count: 1);
      await db.put(doc: Doc(id: 'a', model: {}));
      await db.put(doc: Doc(id: 'b', model: {}));

      db
          .changesStream(ChangeRequest(feed: ChangeFeed.longpoll, since: 'now'))
          .then((stream) async {
        stream.listen(onResult: resultFn, onComplete: completefn);
        await db
            .bulkDocs(body: [Doc(id: 'c', model: {}), Doc(id: 'd', model: {})]);
      });
    });
  });

  testEachAdapter('test-continuous-feed', (ctx) {
    test('Test change stream: continuous feed', () async {
      final db = ctx.db!;
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
  });
}
