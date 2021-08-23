import 'package:json_annotation/json_annotation.dart';

import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';

part 'doc_history.g.dart';

@JsonSerializable(explicitToJson: true)
class RevisionNode {
  String rev;
  String? prevRev;
  String? nextRev;

  RevisionNode({
    required this.rev,
    this.prevRev,
    this.nextRev,
  });

  factory RevisionNode.fromJson(Map<String, dynamic> json) =>
      _$RevisionNodeFromJson(json);
  Map<String, dynamic> toJson() => _$RevisionNodeToJson(this);
}

@JsonSerializable(explicitToJson: true)
class RevisionTree {
  List<RevisionNode> nodes;
  RevisionTree({
    required this.nodes,
  });

  factory RevisionTree.fromJson(Map<String, dynamic> json) =>
      _$RevisionTreeFromJson(json);
  Map<String, dynamic> toJson() => _$RevisionTreeToJson(this);
}

@JsonSerializable(explicitToJson: true)
class InternalDoc {
  String rev;
  bool deleted;
  String localSeq;
  Map<String, dynamic> data;
  InternalDoc({
    required this.rev,
    required this.deleted,
    required this.localSeq,
    required this.data,
  });

  factory InternalDoc.fromJson(Map<String, dynamic> json) =>
      _$InternalDocFromJson(json);
  Map<String, dynamic> toJson() => _$InternalDocToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DocHistory {
  String id;
  Map<String, InternalDoc> docs;
  RevisionTree revisions;

  DocHistory({required this.id, required this.docs, required this.revisions});

  Iterable<InternalDoc> get leafDocs {
    return revisions.nodes
        .where((element) => element.nextRev == null)
        .map((e) => docs[e.rev]!);
  }

  InternalDoc? get winner {
    List<InternalDoc> sortedLeaves = leafDocs.toList();
    sortedLeaves.sort((a, b) => b.rev.compareTo(a.rev));

    return sortedLeaves.length > 0 ? sortedLeaves.first : null;
  }

  RevsDiff revsDiff(List<String> body) {
    List<String> revs = docs.map((e) => e.rev!).toList();
    print(revs.toString());
    List<String> missing = [];
    body.forEach((element) {
      if (!revs.contains(element)) {
        missing.add(element);
      }
    });
    return RevsDiff(missing: missing);
  }

  factory DocHistory.fromJson(Map<String, dynamic> json) =>
      _$DocHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$DocHistoryToJson(this);
}
