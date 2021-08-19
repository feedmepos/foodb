import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';

void main() {
  test("winnerIndex", () {
    var history = DocHistory(docs: []);
    expect(history.winner, isNull);
  });

  test("leafNode", () {
    var history = DocHistory(docs: []);
    history.docs.addAll([
      Doc(
          id: 'a',
          model: {},
          revisions: Revisions(ids: ['a'], start: 1),
          rev: '1-a',
          localSeq: '1'),
      Doc(
          id: 'a',
          model: {},
          revisions: Revisions(ids: ['b', 'a'], start: 2),
          rev: '2-b',
          localSeq: '2'),
      Doc(
          id: 'a',
          model: {},
          revisions: Revisions(ids: ['c', 'b'], start: 3),
          rev: '3-c',
          localSeq: '3'),
      Doc(
          id: 'a',
          model: {},
          revisions: Revisions(ids: ['d', 'c'], start: 4),
          rev: '4-d',
          localSeq: '5'),
      Doc(
          id: 'a',
          model: {},
          revisions: Revisions(ids: ['d', 'c'], start: 4),
          rev: '4-d',
          localSeq: '5')
    ]);
    expect(history.leafDocs.first.rev, '4-d');
  });

  test('winner', () {
    var docHistory = DocHistory(docs: []);
    docHistory.docs.addAll([
      Doc(
          id: 'foo1',
          model: {'a': 'b'},
          revisions: Revisions(start: 1, ids: ['a'])),
      Doc(
          id: 'foo2',
          model: {'c': 'd'},
          revisions: Revisions(start: 2, ids: ['b'])),
      Doc(
          id: 'foo3',
          model: {'e': 'f'},
          revisions: Revisions(start: 3, ids: ['c']),
          deleted: true)
    ]);
    expect(docHistory.winner?.revisions?.start, 3);
  });

  test('conflict and deleted conflict', () {
    var docHistory = DocHistory<Map<String, dynamic>>(docs: []);
    docHistory.docs.addAll([
      Doc(
          id: 'foo1',
          model: {'a': 'b'},
          rev: '2-b',
          revisions: Revisions(start: 2, ids: ['b', 'a'])),
      Doc(
          id: 'foo2',
          model: {'c': 'd'},
          rev: '1-bb',
          revisions: Revisions(start: 1, ids: ['bb'])),
      Doc(
          id: 'foo3',
          model: {'e': 'f'},
          rev: '5-abc',
          revisions:
              Revisions(start: 5, ids: ['abc', 'def', 'ghi', 'jkl', 'mno']))
    ]);
    expect(docHistory.leafDocs.length, 3);
    expect(docHistory.leafDocs.first.rev, '5-abc');
  });
}
