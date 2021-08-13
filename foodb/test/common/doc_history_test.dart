import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';

void main() {
  test("winnerIndex", () {
    var history = DocHistory(winnerIndex: 0, docs: []);
    expect(history.winner, isNull);
  });
  test("leafNode", () {
    var history = DocHistory(winnerIndex: 0, docs: []);
    history.docs.add(Doc(
        id: '1',
        rev: '1-1',
        model: {},
        revisions: Revisions(start: 1, ids: ["1"])));
    history.docs.add(Doc(
        id: '1',
        rev: '2-2',
        model: {},
        revisions: Revisions(start: 2, ids: ["2", "1"])));
    expect(history.leafDocs.length, 1);
    expect(history.leafDocs[0].rev, '2-2');
    // TEST different sacnario
  });

  test('winner', () {
    // TODO, remove winner index, make it computed
    // get all leave nodes
    // remove deleted
    // sort by ids[0]
    // sort by rivision start
  });
}
