import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'doc_history.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class DocHistory<T> {
  int winnerIndex;
  List<Doc<T>> docs;
  DocHistory({
    required this.winnerIndex,
    required this.docs,
  });

  Doc<T>? get winner => winnerIndex < docs.length ? docs[winnerIndex] : null;

  List<Doc<T>> get leafDocs {
    var sorted = docs.toList();
    List<Doc<T>> leave = [];
    sorted.sort((a, b) => b.revisions!.start - a.revisions!.start);
    while (sorted.length > 0) {
      var leaf = sorted.first;
      leave.add(leaf);
      sorted.remove(0);
      for (String md5 in leaf.revisions!.ids) {
        sorted.removeWhere((element) => Rev.parse(element.rev!).md5 == md5);
      }
    }
    return leave;
  }

  factory DocHistory.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$DocHistoryFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$DocHistoryToJson(this, toJsonT);

  DocHistory<T> copyWith({
    int? winnerIndex,
    List<Doc<T>>? docs,
  }) {
    return DocHistory<T>(
      winnerIndex: winnerIndex ?? this.winnerIndex,
      docs: docs ?? this.docs,
    );
  }
}
