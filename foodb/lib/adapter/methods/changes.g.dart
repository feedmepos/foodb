// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangeResultRev _$ChangeResultRevFromJson(Map<String, dynamic> json) {
  return ChangeResultRev(
    rev: RevFromJsonString(json['rev'] as String?),
  );
}

Map<String, dynamic> _$ChangeResultRevToJson(ChangeResultRev instance) =>
    <String, dynamic>{
      'rev': RevToJsonString(instance.rev),
    };

ChangeResult _$ChangeResultFromJson(Map<String, dynamic> json) {
  return ChangeResult(
    id: json['id'] as String,
    seq: json['seq'] as String,
    deleted: json['deleted'] as bool?,
    changes: (json['changes'] as List<dynamic>)
        .map((e) => ChangeResultRev.fromJson(e as Map<String, dynamic>))
        .toList(),
    doc: json['doc'] == null
        ? null
        : Doc.fromJson(json['doc'] as Map<String, dynamic>,
            (value) => value as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$ChangeResultToJson(ChangeResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'seq': instance.seq,
      'deleted': instance.deleted,
      'changes': instance.changes.map((e) => e.toJson()).toList(),
      'doc': instance.doc?.toJson(
        (value) => value,
      ),
    };

ChangeResponse _$ChangeResponseFromJson(Map<String, dynamic> json) {
  return ChangeResponse(
    lastSeq: json['last_seq'] as String?,
    pending: json['pending'] as int?,
    results: (json['results'] as List<dynamic>)
        .map((e) => ChangeResult.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$ChangeResponseToJson(ChangeResponse instance) =>
    <String, dynamic>{
      'last_seq': instance.lastSeq,
      'pending': instance.pending,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };

ChangeRequest _$ChangeRequestFromJson(Map<String, dynamic> json) {
  return ChangeRequest(
    docIds:
        (json['doc_ids'] as List<dynamic>?)?.map((e) => e as String).toList(),
    conflicts: json['conflicts'] as bool,
    descending: json['descending'] as bool,
    feed: json['feed'] as String,
    filter: json['filter'] as String?,
    heartbeat: json['heartbeat'] as int,
    includeDocs: json['include_docs'] as bool,
    attachments: json['attachments'] as bool,
    attEncodingInfo: json['att_encoding_info'] as bool,
    lastEventId: json['last_event_id'] as int?,
    limit: json['limit'] as int?,
    since: json['since'] as String,
    style: json['style'] as String,
    timeout: json['timeout'] as int,
    view: json['view'] as String?,
    seqInterval: json['seq_interval'] as int?,
  );
}

Map<String, dynamic> _$ChangeRequestToJson(ChangeRequest instance) =>
    <String, dynamic>{
      'doc_ids': instance.docIds,
      'conflicts': instance.conflicts,
      'descending': instance.descending,
      'feed': instance.feed,
      'filter': instance.filter,
      'heartbeat': instance.heartbeat,
      'include_docs': instance.includeDocs,
      'attachments': instance.attachments,
      'att_encoding_info': instance.attEncodingInfo,
      'last_event_id': instance.lastEventId,
      'limit': instance.limit,
      'since': instance.since,
      'style': instance.style,
      'timeout': instance.timeout,
      'view': instance.view,
      'seq_interval': instance.seqInterval,
    };
