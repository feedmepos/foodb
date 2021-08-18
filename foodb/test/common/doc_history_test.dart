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
          id: '1',
          rev: '1-1',
          model: {},
          revisions: Revisions(start: 1, ids: ["1"])),
      Doc(
          id: '1',
          rev: '2-2',
          model: {},
          revisions: Revisions(start: 2, ids: ["2", "1"]))
    ]);
    history.docs.addAll([
      Doc(
          id: '1',
          rev: '1-1',
          model: {},
          revisions: Revisions(start: 1, ids: ["a"])),
      Doc(
          id: '1',
          rev: '2-a',
          model: {},
          revisions: Revisions(start: 2, ids: ["a", "a"])),
      Doc(
          id: '1',
          rev: '2-b',
          model: {},
          revisions: Revisions(start: 2, ids: ["b", "a"]))
    ]);
    expect(history.leafDocs.length, 1);
    expect(history.leafDocs.first.rev, '2-2');
    // TODO: TEST different sacnario
  });

  test('winner', () {
    // TODO, remove winner index, make it computed
    // get all leave nodes
    // remove deleted
    // sort by ids[0]
    // sort by rivision start
  });

  test('conflict and deleted conflict', () {
    // TODO, remove winner index, make it computed
    // get all leave nodes
    // remove deleted
    // sort by ids[0]
    // sort by rivision start
  });
}
