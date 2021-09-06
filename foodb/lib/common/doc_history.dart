import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'doc_history.g.dart';

@JsonSerializable(explicitToJson: true)
class RevisionNode {
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev rev;
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev? prevRev;

  RevisionNode({
    required this.rev,
    this.prevRev,
  });

  factory RevisionNode.fromJson(Map<String, dynamic> json) =>
      _$RevisionNodeFromJson(json);
  Map<String, dynamic> toJson() => _$RevisionNodeToJson(this);

  RevisionNode copyWith({
    Rev? rev,
    Rev? prevRev,
  }) {
    return RevisionNode(
      rev: rev ?? this.rev,
      prevRev: prevRev ?? this.prevRev,
    );
  }
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

  RevisionTree copyWith({
    List<RevisionNode>? nodes,
  }) {
    return RevisionTree(
      nodes: nodes ?? this.nodes,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class InternalDoc {
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev rev;
  bool deleted;
  String? localSeq;
  Map<String, dynamic> data;
  InternalDoc({
    required this.rev,
    required this.deleted,
    this.localSeq,
    required this.data,
  });

  factory InternalDoc.fromJson(Map<String, dynamic> json) =>
      _$InternalDocFromJson(json);
  Map<String, dynamic> toJson() => _$InternalDocToJson(this);

  InternalDoc copyWith({
    Rev? rev,
    bool? deleted,
    String? localSeq,
    Map<String, dynamic>? data,
  }) {
    return InternalDoc(
      rev: rev ?? this.rev,
      deleted: deleted ?? this.deleted,
      localSeq: localSeq ?? this.localSeq,
      data: data ?? this.data,
    );
  }

  Doc<T> toDoc<T>(String id, T Function(Map<String, dynamic> json) fromT,
      {Revisions? revisions}) {
    return Doc(
        id: id,
        model: fromT(this.data),
        rev: this.rev,
        deleted: this.deleted,
        revisions: revisions);
  }
}

@JsonSerializable(explicitToJson: true)
class DocHistory {
  String id;
  Map<String, InternalDoc> docs;
  RevisionTree revisions;
  DocHistory({
    required this.id,
    required this.docs,
    required this.revisions,
  });

  Iterable<InternalDoc> get leafDocs {
    Map<String, InternalDoc> leaf = Map.from(docs);
    revisions.nodes.forEach((element) {
      leaf.remove(element.prevRev.toString());
    });
    return leaf.values;
  }

  InternalDoc? get winner {
    List<InternalDoc> sortedLeaves = leafDocs.toList();
    sortedLeaves.removeWhere((element) => element.deleted == true);
    sortedLeaves.sort((a, b) => b.rev.compareTo(a.rev));

    return sortedLeaves.length > 0 ? sortedLeaves.first : null;
  }

  Revisions? getRevision(Rev rev) {
    List<RevisionNode> nodes =
        this.revisions.nodes.where((element) => element.rev == rev).toList();

    if (nodes.length == 0) return null;
    RevisionNode current = nodes[0];
    Revisions revisions =
        new Revisions(ids: [current.rev.md5], start: current.rev.index);

    while (current.prevRev != null) {
      revisions.ids.add(current.prevRev!.md5);
      current = this
          .revisions
          .nodes
          .where((element) => element.rev == rev)
          .toList()[0];
    }
    return revisions;
  }

  RevsDiff revsDiff(List<String> body) {
    List<String> revs = docs.values.map((v) => v.rev.toString()).toList();
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

  DocHistory copyWith({
    String? id,
    Map<String, InternalDoc>? docs,
    RevisionTree? revisions,
  }) {
    return DocHistory(
      id: id ?? this.id,
      docs: docs ?? this.docs,
      revisions: revisions ?? this.revisions,
    );
  }
}
