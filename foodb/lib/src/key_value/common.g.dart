// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompactionMeta _$CompactionMetaFromJson(Map<String, dynamic> json) {
  return CompactionMeta(
    lastSeq: json['lastSeq'] as int,
    revLimit: json['revLimit'] as int,
  );
}

Map<String, dynamic> _$CompactionMetaToJson(CompactionMeta instance) =>
    <String, dynamic>{
      'lastSeq': instance.lastSeq,
      'revLimit': instance.revLimit,
    };

ViewMeta _$ViewMetaFromJson(Map<String, dynamic> json) {
  return ViewMeta(
    lastSeq: json['lastSeq'] as int,
  );
}

Map<String, dynamic> _$ViewMetaToJson(ViewMeta instance) => <String, dynamic>{
      'lastSeq': instance.lastSeq,
    };

ViewDocMeta _$ViewDocMetaFromJson(Map<String, dynamic> json) {
  return ViewDocMeta(
    keys: ListOfViewKeyMetaFromJsonString(json['keys'] as String),
  );
}

Map<String, dynamic> _$ViewDocMetaToJson(ViewDocMeta instance) =>
    <String, dynamic>{
      'keys': ListOfViewKeyMetaToJsonString(instance.keys),
    };

UpdateSequence _$UpdateSequenceFromJson(Map<String, dynamic> json) {
  return UpdateSequence(
    id: json['id'] as String,
    winnerRev: RevFromJsonString(json['winnerRev'] as String?),
    allLeafRev: ListOfRevFromJsonString(json['allLeafRev'] as List),
    deleted: json['deleted'] as bool?,
  );
}

Map<String, dynamic> _$UpdateSequenceToJson(UpdateSequence instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deleted': instance.deleted,
      'winnerRev': RevToJsonString(instance.winnerRev),
      'allLeafRev': ListOfRevToJsonString(instance.allLeafRev),
    };

RevisionNode _$RevisionNodeFromJson(Map<String, dynamic> json) {
  return RevisionNode(
    rev: RevFromJsonString(json['rev'] as String?),
    prevRev: RevFromJsonString(json['prevRev'] as String?),
  );
}

Map<String, dynamic> _$RevisionNodeToJson(RevisionNode instance) =>
    <String, dynamic>{
      'rev': RevToJsonString(instance.rev),
      'prevRev': RevToJsonString(instance.prevRev),
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
    rev: RevFromJsonString(json['rev'] as String?),
    deleted: json['deleted'] as bool,
    localSeq: json['localSeq'] as int?,
    data: json['data'] as Map<String, dynamic>,
  );
}

Map<String, dynamic> _$InternalDocToJson(InternalDoc instance) =>
    <String, dynamic>{
      'rev': RevToJsonString(instance.rev),
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
