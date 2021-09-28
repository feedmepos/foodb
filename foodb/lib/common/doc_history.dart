import 'package:foodb/adapter/exception.dart';
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
  int? localSeq;
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
    int? localSeq,
    Map<String, dynamic>? data,
  }) {
    return InternalDoc(
      rev: rev ?? this.rev,
      deleted: deleted ?? this.deleted,
      localSeq: localSeq ?? this.localSeq,
      data: data ?? this.data,
    );
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

  Doc<T> toDoc<T>(Rev rev, T Function(Map<String, dynamic> json) fromT,
      {bool revs = false, bool revsInfo = false}) {
    final doc = docs[rev.toString()];
    if (doc == null) {
      throw AdapterException(error: 'missing', reason: 'document not found');
    }
    Revisions? _revisions;
    if (revs == true) {
      _revisions = getRevision(rev)!;
    }
    List<RevsInfo>? _revsInfo;
    if (revsInfo == true && _revisions != null) {
      _revsInfo = [];
      var index = _revisions.start;
      for (final id in _revisions.ids) {
        final rev = Rev(index: index, md5: id);
        if (docs[rev.toString()] != null) {
          _revsInfo.add(RevsInfo(rev: rev, status: 'available'));
        } else {
          _revsInfo.add(RevsInfo(rev: rev, status: 'missing'));
        }
        index -= 1;
      }
    }
    return Doc(
      id: id,
      model: fromT(doc.data),
      rev: doc.rev,
      deleted: doc.deleted,
      revisions: _revisions,
      revsInfo: _revsInfo,
    );
  }

  RevsDiff revsDiff(List<Rev> body) {
    List<Rev> revs = docs.values.map((v) => v.rev).toList();
    List<Rev> missing = [];
    body.forEach((element) {
      Rev rev = Rev.fromString(element);
      if (!revs.contains(rev)) {
        missing.add(rev);
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
