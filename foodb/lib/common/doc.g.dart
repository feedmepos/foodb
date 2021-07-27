// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Doc _$DocFromJson(Map<String, dynamic> json) {
  return Doc(
    id: json['_id'] as String,
    rev: json['_rev'] as String,
    deleted: json['_deleted'] as bool?,
    revisions: json['_revisions'] == null
        ? null
        : Revisions.fromJson(json['_revisions'] as Map<String, dynamic>),
    json: json['json'] as Map<String, dynamic>?,
    attachments: json['_attachments'],
    conflicts: (json['_conflicts'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    deletedConflicts: (json['_deleted_conflicts'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    revsInfo: (json['_revs_info'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(k, e as Object),
            ))
        .toList(),
    localSeq: json['_local_seq'] as String?,
  );
}

Map<String, dynamic> _$DocToJson(Doc instance) => <String, dynamic>{
      '_id': instance.id,
      '_rev': instance.rev,
      '_deleted': instance.deleted,
      '_revisions': instance.revisions,
      'json': instance.json,
      '_attachments': instance.attachments,
      '_conflicts': instance.conflicts,
      '_deleted_conflicts': instance.deletedConflicts,
      '_revs_info': instance.revsInfo,
      '_local_seq': instance.localSeq,
    };

Revisions _$RevisionsFromJson(Map<String, dynamic> json) {
  return Revisions(
    start: json['start'] as int,
    ids: (json['ids'] as List<dynamic>).map((e) => e as String).toList(),
  );
}

Map<String, dynamic> _$RevisionsToJson(Revisions instance) => <String, dynamic>{
      'start': instance.start,
      'ids': instance.ids,
    };
