// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doc_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevisionNode _$RevisionNodeFromJson(Map<String, dynamic> json) {
  return RevisionNode(
    rev: json['rev'] as String,
    prevRev: json['prevRev'] as String?,
    nextRev: json['nextRev'] as String?,
  );
}

Map<String, dynamic> _$RevisionNodeToJson(RevisionNode instance) =>
    <String, dynamic>{
      'rev': instance.rev,
      'prevRev': instance.prevRev,
      'nextRev': instance.nextRev,
    };

RevisionTree _$RevisionTreeFromJson(Map<String, dynamic> json) {
  return RevisionTree(
    nodes: (json['nodes'] as List<dynamic>)
        .map((e) => RevisionNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$RevisionTreeToJson(RevisionTree instance) =>
    <String, dynamic>{
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
    };

InternalDoc _$InternalDocFromJson(Map<String, dynamic> json) {
  return InternalDoc(
    rev: json['rev'] as String,
    deleted: json['deleted'] as bool,
    localSeq: json['localSeq'] as String,
    data: json['data'] as Map<String, dynamic>,
  );
}

Map<String, dynamic> _$InternalDocToJson(InternalDoc instance) =>
    <String, dynamic>{
      'rev': instance.rev,
      'deleted': instance.deleted,
      'localSeq': instance.localSeq,
      'data': instance.data,
    };

DocHistory _$DocHistoryFromJson(Map<String, dynamic> json) {
  return DocHistory(
    id: json['id'] as String,
    docs: (json['docs'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, InternalDoc.fromJson(e as Map<String, dynamic>)),
    ),
    revisions: RevisionTree.fromJson(json['revisions'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$DocHistoryToJson(DocHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'docs': instance.docs.map((k, e) => MapEntry(k, e.toJson())),
      'revisions': instance.revisions.toJson(),
    };
