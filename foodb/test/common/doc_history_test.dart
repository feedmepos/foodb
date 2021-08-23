import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/rev.dart';

void main() {
  test('revsDiff', () async {
    DocHistory history = DocHistory(
        id: 'a',
        docs: {
          "1-a": InternalDoc(
              rev: Rev.fromString("1-a"),
              deleted: false,
              localSeq: "1",
              data: {}),
          "2-b": InternalDoc(
              rev: Rev.fromString("2-b"),
              deleted: false,
              localSeq: "2",
              data: {}),
          "3-c": InternalDoc(
              rev: Rev.fromString("3-c"),
              deleted: false,
              localSeq: "3",
              data: {}),
          "4-d": InternalDoc(
              rev: Rev.fromString("4-d"),
              deleted: false,
              localSeq: "4",
              data: {})
        },
        revisions: RevisionTree(nodes: [
          RevisionNode(rev: Rev.fromString('1-a')),
          RevisionNode(
              rev: Rev.fromString('2-b'), prevRev: Rev.fromString('1-a')),
          RevisionNode(
              rev: Rev.fromString('3-c'), prevRev: Rev.fromString('2-b')),
          RevisionNode(
              rev: Rev.fromString('4-d'), prevRev: Rev.fromString('3-c'))
        ]));

    RevsDiff revsDiff =
        await history.revsDiff(["1-a", "4-c", "1-c", "4-d", "5-e"]);

    expect(history.docs.length, equals(4));

    print(revsDiff.toJson());
    expect(revsDiff.missing.length, 3);
  });

  test("leafdocs", () async {
    DocHistory history = DocHistory(
        id: 'a',
        docs: {
          "1-a": InternalDoc(
              rev: Rev.fromString("1-a"),
              deleted: false,
              localSeq: "1",
              data: {}),
          "2-b": InternalDoc(
              rev: Rev.fromString("2-b"),
              deleted: false,
              localSeq: "2",
              data: {}),
          "3-c": InternalDoc(
              rev: Rev.fromString("3-c"),
              deleted: false,
              localSeq: "3",
              data: {}),
          "4-d": InternalDoc(
              rev: Rev.fromString("4-d"),
              deleted: false,
              localSeq: "4",
              data: {})
        },
        revisions: RevisionTree(nodes: [
          RevisionNode(rev: Rev.fromString("1-a")),
          RevisionNode(
              rev: Rev.fromString("2-b"), prevRev: Rev.fromString("1-a")),
          RevisionNode(
              rev: Rev.fromString("3-c"), prevRev: Rev.fromString("2-b")),
          RevisionNode(
              rev: Rev.fromString("4-d"), prevRev: Rev.fromString("3-c"))
        ]));

    print(history.winner?.toJson());

    for (InternalDoc doc in history.leafDocs) {
      print(doc.rev);
    }
    expect(history.leafDocs.length, 1);
    expect(history.winner?.rev.toString(), "4-d");
  });
  group('winner', () {
    test("test with single leaf doc", () async {
      DocHistory history = DocHistory(
          id: 'a',
          docs: {
            "1-a": InternalDoc(
                rev: Rev.fromString("1-a"),
                deleted: false,
                localSeq: "1",
                data: {}),
            "2-b": InternalDoc(
                rev: Rev.fromString("2-b"),
                deleted: false,
                localSeq: "2",
                data: {}),
            "3-c": InternalDoc(
                rev: Rev.fromString("3-c"),
                deleted: false,
                localSeq: "3",
                data: {}),
            "4-d": InternalDoc(
                rev: Rev.fromString("4-d"),
                deleted: false,
                localSeq: "4",
                data: {})
          },
          revisions: RevisionTree(nodes: [
            RevisionNode(rev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-b"), prevRev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("3-c"), prevRev: Rev.fromString("2-b")),
            RevisionNode(
                rev: Rev.fromString("4-d"), prevRev: Rev.fromString("3-c"))
          ]));

      for (InternalDoc doc in history.leafDocs) {
        print(doc.rev);
      }
      expect(history.leafDocs.length, 1);
      expect(history.winner?.rev.toString(), "4-d");
    });

    test("test with 2 different length leafdocs", () async {
      DocHistory history = DocHistory(
          id: 'a',
          docs: {
            "1-a": InternalDoc(
                rev: Rev.fromString("1-a"),
                deleted: false,
                localSeq: "1",
                data: {}),
            "2-b": InternalDoc(
                rev: Rev.fromString("2-b"),
                deleted: false,
                localSeq: "2",
                data: {}),
            "3-c": InternalDoc(
                rev: Rev.fromString("3-c"),
                deleted: false,
                localSeq: "3",
                data: {}),
            "4-d": InternalDoc(
                rev: Rev.fromString("2-d"),
                deleted: false,
                localSeq: "4",
                data: {})
          },
          revisions: RevisionTree(nodes: [
            RevisionNode(rev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-b"), prevRev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("3-c"), prevRev: Rev.fromString("2-b")),
            RevisionNode(
                rev: Rev.fromString("2-d"), prevRev: Rev.fromString("1-a"))
          ]));

      for (InternalDoc doc in history.leafDocs) {
        print(doc.rev);
      }
      expect(history.leafDocs.length, 2);
      expect(history.winner?.rev.toString(), "3-c");
    });
    test('test with 3 same length leafdocs', () async {
      DocHistory history = DocHistory(
          id: 'a',
          docs: {
            "1-a": InternalDoc(
                rev: Rev.fromString("1-a"),
                deleted: false,
                localSeq: "1",
                data: {}),
            "2-b": InternalDoc(
                rev: Rev.fromString("2-b"),
                deleted: false,
                localSeq: "2",
                data: {}),
            "3-c": InternalDoc(
                rev: Rev.fromString("2-d"),
                deleted: false,
                localSeq: "3",
                data: {}),
            "4-d": InternalDoc(
                rev: Rev.fromString("2-c"),
                deleted: false,
                localSeq: "4",
                data: {})
          },
          revisions: RevisionTree(nodes: [
            RevisionNode(rev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-b"), prevRev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-d"), prevRev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-c"), prevRev: Rev.fromString("1-a"))
          ]));

      for (InternalDoc doc in history.leafDocs) {
        print(doc.rev);
      }
      expect(history.leafDocs.length, 3);
      expect(history.winner?.rev.toString(), "2-d");
    });

    test('test with 3 same length leafdocs with deleted= true', () async {
      DocHistory history = DocHistory(
          id: 'a',
          docs: {
            "1-a": InternalDoc(
                rev: Rev.fromString("1-a"),
                deleted: false,
                localSeq: "1",
                data: {}),
            "2-b": InternalDoc(
                rev: Rev.fromString("2-b"),
                deleted: false,
                localSeq: "2",
                data: {}),
            "3-c": InternalDoc(
                rev: Rev.fromString("2-d"),
                deleted: true,
                localSeq: "3",
                data: {}),
            "4-d": InternalDoc(
                rev: Rev.fromString("2-c"),
                deleted: false,
                localSeq: "4",
                data: {})
          },
          revisions: RevisionTree(nodes: [
            RevisionNode(rev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-b"), prevRev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-d"), prevRev: Rev.fromString("1-a")),
            RevisionNode(
                rev: Rev.fromString("2-c"), prevRev: Rev.fromString("1-a"))
          ]));

      for (InternalDoc doc in history.leafDocs) {
        print(doc.rev);
      }
      expect(history.leafDocs.length, 3);
      expect(history.winner?.rev.toString(), "2-c");
    });
  });
}
