import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'doc.g.dart';

@immutable
class Doc<T> {
  @JsonKey(name: '_id')
  final String id;

  @JsonKey(name: '_rev')
  final String? rev;

  @JsonKey(name: '_deleted')
  final bool? deleted;

  @JsonKey(name: '_revisions')
  final Revisions? revisions;

  final T model;

  @JsonKey(name: '_attachments')
  final Object? attachments;

  @JsonKey(name: '_conflicts')
  final List<String>? conflicts;

  @JsonKey(name: '_deleted_conflicts')
  final List<String>? deletedConflicts;

  @JsonKey(name: '_revs_info')
  final List<Map<String, Object>>? revsInfo;

  @JsonKey(name: '_local_seq')
  final String? localSeq;

  Doc({
    required this.id,
    this.rev,
    required this.model,
    this.deleted,
    this.revisions,
    this.attachments,
    this.conflicts,
    this.deletedConflicts,
    this.revsInfo,
    this.localSeq,
  });

  factory Doc.fromJson(
          Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$DocFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$DocToJson(this, toJsonT);

  Doc<T> copyWith(
      {String? id,
      String? rev,
      bool? deleted,
      Revisions? revisions,
      T? model,
      Object? attachments,
      List<String>? conflicts,
      List<String>? deletedConflicts,
      List<Map<String, Object>>? revsInfo,
      String? localSeq}) {
    return Doc<T>(
        id: id ?? this.id,
        rev: rev ?? this.rev,
        model: model ?? this.model,
        deleted: deleted ?? this.deleted,
        revisions: revisions ?? this.revisions,
        attachments: attachments ?? this.attachments,
        conflicts: conflicts ?? this.conflicts,
        deletedConflicts: deletedConflicts ?? this.deletedConflicts,
        revsInfo: revsInfo ?? this.revsInfo,
        localSeq: localSeq ?? this.localSeq);
  }
}

Doc<T> _$DocFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return Doc<T>(
    id: json['_id'] as String,
    rev: json['_rev'] as String?,
    model: fromJsonT(json),
    deleted: json['_deleted'] as bool?,
    revisions: json['_revisions'] == null
        ? null
        : Revisions.fromJson(json['_revisions'] as Map<String, dynamic>),
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

Map<String, dynamic> _$DocToJson<T>(
  Doc<T> instance,
  Object? Function(T value) toJsonT,
) {
  Map<String, dynamic> map = toJsonT(instance.model) as Map<String, dynamic>;
  map.addAll(<String, dynamic>{
    '_id': instance.id,
    '_rev': instance.rev,
    '_deleted': instance.deleted,
    '_revisions': instance.revisions,
    '_attachments': instance.attachments,
    '_conflicts': instance.conflicts,
    '_deleted_conflicts': instance.deletedConflicts,
    '_revs_info': instance.revsInfo,
    '_local_seq': instance.localSeq,
  });
  return map;
}

@JsonSerializable()
@immutable
class Revisions {
  final int start;
  final List<String> ids;
  Revisions({
    required this.start,
    required this.ids,
  });
  factory Revisions.fromJson(Map<String, dynamic> json) =>
      _$RevisionsFromJson(json);
  Map<String, dynamic> toJson() => _$RevisionsToJson(this);
}
