import 'dart:math';

import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'common.g.dart';

@JsonSerializable()
class CompactionMeta {
  int lastSeq;
  int revLimit;
  CompactionMeta({
    required this.lastSeq,
    required this.revLimit,
  });

  factory CompactionMeta.fromJson(Map<String, dynamic> json) =>
      _$CompactionMetaFromJson(json);
  Map<String, dynamic> toJson() => _$CompactionMetaToJson(this);
}

@JsonSerializable()
class ViewMeta {
  int lastSeq;

  ViewMeta({required this.lastSeq});

  factory ViewMeta.fromJson(Map<String, dynamic> json) =>
      _$ViewMetaFromJson(json);
  Map<String, dynamic> toJson() => _$ViewMetaToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ViewDocMeta {
  @JsonKey(
      fromJson: ListOfViewKeyMetaFromJsonString,
      toJson: ListOfViewKeyMetaToJsonString)
  List<ViewKeyMeta> keys;

  ViewDocMeta({required this.keys});

  factory ViewDocMeta.fromJson(Map<String, dynamic> json) =>
      _$ViewDocMetaFromJson(json);
  Map<String, dynamic> toJson() => _$ViewDocMetaToJson(this);
}

@JsonSerializable()
class UpdateSequence {
  String id;

  bool? deleted;

  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  Rev winnerRev;

  @JsonKey(fromJson: ListOfRevFromJsonString, toJson: ListOfRevToJsonString)
  List<Rev> allLeafRev;

  UpdateSequence(
      {required this.id,
      required this.winnerRev,
      required this.allLeafRev,
      this.deleted});

  factory UpdateSequence.fromJson(Map<String, dynamic> json) =>
      _$UpdateSequenceFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateSequenceToJson(this);
}

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

  Iterable<InternalDoc> get allConflicts {
    return leafDocs.where((element) => element.rev != winner?.rev);
  }

  Iterable<InternalDoc> get conflicts {
    return allConflicts.where((element) => !element.deleted);
  }

  Iterable<InternalDoc> get deletedConflicts {
    return allConflicts.where((element) => element.deleted);
  }

  Rev? get winnerRev {
    return winner?.rev;
  }

  InternalDoc? get winnerWithDeleted {
    List<InternalDoc> sortedLeaves = leafDocs.toList();
    sortedLeaves.sort((a, b) => b.rev.compareTo(a.rev));
    return sortedLeaves.length > 0 ? sortedLeaves.first : null;
  }

  InternalDoc? get winner {
    List<InternalDoc> sortedLeaves = leafDocs.toList();
    sortedLeaves.removeWhere((element) => element.deleted == true);
    sortedLeaves.sort((a, b) => b.rev.compareTo(a.rev));

    return sortedLeaves.length > 0 ? sortedLeaves.first : null;
  }

  Revisions? getRevision(Rev rev, [int? revLimit]) {
    List<RevisionNode> nodes =
        revisions.nodes.where((element) => element.rev == rev).toList();

    if (nodes.length == 0) return null;
    RevisionNode current = nodes[0];
    Revisions result =
        new Revisions(ids: [current.rev.md5], start: current.rev.index);

    while (current.prevRev != null) {
      result.ids.add(current.prevRev!.md5);
      current = revisions.nodes
          .where((element) => element.rev == current.prevRev)
          .toList()[0];
    }
    return result;
  }

  Doc<T>? toDoc<T>(Rev rev, T Function(Map<String, dynamic> json) fromT,
      {required revLimit,
      bool showRevision = false,
      bool showRevInfo = false,
      showConflicts = false}) {
    final doc = docs[rev.toString()];
    if (doc == null) {
      return null;
    }
    Revisions? _revisions = getRevision(rev);
    List<RevsInfo>? _revsInfo;
    if (_revisions == null) {
      return null;
    }
    if (showRevInfo == true && winnerRev == rev) {
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
        revisions: showRevision
            ? Revisions(
                start: _revisions.start,
                ids: _revisions.ids
                    .sublist(0, min(revLimit, _revisions.ids.length)))
            : null,
        revsInfo: _revsInfo,
        deletedConflicts: showConflicts && deletedConflicts.length > 0
            ? deletedConflicts.map((e) => e.rev).toList()
            : null,
        conflicts: showConflicts && conflicts.length > 0
            ? conflicts.map((e) => e.rev).toList()
            : null);
  }

  RevsDiff revsDiff(List<Rev> body) {
    List<Rev> revs = docs.values.map((v) => v.rev).toList();
    List<Rev> missing = [];
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
    int? lastSeq,
  }) {
    return DocHistory(
      id: id ?? this.id,
      docs: docs ?? this.docs,
      revisions: revisions ?? this.revisions,
    );
  }

  DocHistory compact(int limit) {
    final newDocs = Map<String, InternalDoc>();
    List<RevisionNode> newNodes = [];
    leafDocs.forEach((doc) {
      var i = 0;
      newDocs[doc.rev.toString()] = doc;
      Rev? currRev = doc.rev;
      do {
        var nodeToAdd = revisions.nodes
            .firstWhere((element) => element.rev == currRev)
            .copyWith();
        ++i;
        if (i >= limit) {
          nodeToAdd.prevRev = null;
        }
        newNodes.add(nodeToAdd);
        currRev = nodeToAdd.prevRev;
      } while (currRev != null);
    });

    return this
        .copyWith(revisions: RevisionTree(nodes: newNodes), docs: newDocs);
  }
}
