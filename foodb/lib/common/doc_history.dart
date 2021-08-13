import 'package:json_annotation/json_annotation.dart';

import 'package:foodb/common/doc.dart';

part 'doc_history.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class DocHistory<T> {
  int winnerIndex;
  List<Doc<T>> docs;
  DocHistory({
    required this.winnerIndex,
    required this.docs,
  });

  Doc<T> get winner => docs[winnerIndex];

  factory DocHistory.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$DocHistoryFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$DocHistoryToJson(this, toJsonT);
}
