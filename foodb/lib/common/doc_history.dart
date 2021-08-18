import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'doc_history.g.dart';

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class DocHistory<T> {
  List<Doc<T>> docs;

  DocHistory({
    required this.docs,
  });

  Doc<T>? get winner => docs.length > 0 ? docs[docs.length - 1] : null;

  Iterable<Doc<T>> get leafDocs sync* {
    var sorted = docs.toList();
    sorted.sort((a, b) => b.revisions!.start - a.revisions!.start);
    while (sorted.length > 0) {
      var leaf = sorted.first;
      sorted.removeAt(0);
      sorted.removeWhere((e) =>
          e.deleted == true ||
          leaf.revisions!.ids.contains(Rev.parse(e.rev!).md5));
      yield leaf;
    }
  }

  factory DocHistory.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$DocHistoryFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$DocHistoryToJson(this, toJsonT);

  DocHistory<T> copyWith({
    List<Doc<T>>? docs,
  }) {
    return DocHistory<T>(
      docs: docs ?? this.docs,
    );
  }
}
