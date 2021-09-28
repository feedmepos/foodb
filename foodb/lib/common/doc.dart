import 'package:flutter/cupertino.dart';
import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'doc.g.dart';

//@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
@immutable
class Doc<T> {
  final String id;
  final Rev? rev;
  final bool? deleted;
  final Revisions? revisions;
  final T model;
  final Object? attachments;
  final List<Rev>? conflicts;
  final List<String>? deletedConflicts;
  final List<RevsInfo>? revsInfo;
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
      Map<String, dynamic> json, T Function(Object? json) fromJsonT) {
    return Doc<T>(
      id: json['_id'] as String,
      rev: json['_rev'] == null ? null : RevFromJsonString(json['_rev']),
      model: fromJsonT(json),
      deleted: json['_deleted'] as bool?,
      revisions: json['_revisions'] == null
          ? null
          : Revisions.fromJson(json['_revisions'] as Map<String, dynamic>),
      attachments: json['_attachments'],
      conflicts: (json['_conflicts'] as List<dynamic>?)
          ?.map((e) => RevFromJsonString(e) as Rev)
          .toList(),
      deletedConflicts: (json['_deleted_conflicts'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      revsInfo: (json['_revs_info'] as List<dynamic>?)
          ?.map((e) => RevsInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      localSeq: json['_local_seq'] as String?,
    );
  }
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    Map<String, dynamic> map = toJsonT(this.model) as Map<String, dynamic>;

    final reservedMetaKey = [
      '_id',
      '_rev',
      '_deleted',
      '_revisions',
      '_attachments',
      '_conflicts',
      '_deleted_conflicts',
      '_revs_info',
      '_local_seq'
    ];

    for (var key in reservedMetaKey) {
      map.remove(key);
    }

    Map<String, dynamic> configurableMeta = {
      '_id': this.id,
      '_rev': RevToJsonString(this.rev),
      '_deleted': this.deleted,
      '_revisions': this.revisions?.toJson(),
    };

    configurableMeta.removeWhere((key, value) => value == null);
    map.addAll(configurableMeta);

    return map;
  }

  Doc<T> copyWith({
    T? model,
    bool? deleted,
    Revisions? revisions,
  }) {
    return Doc<T>(
        id: this.id,
        rev: this.rev,
        model: model ?? this.model,
        deleted: deleted ?? this.deleted,
        revisions: revisions ?? this.revisions,
        attachments: this.attachments,
        conflicts: this.conflicts,
        deletedConflicts: this.deletedConflicts,
        revsInfo: this.revsInfo,
        localSeq: this.localSeq);
  }
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

@JsonSerializable()
@immutable
class RevsInfo {
  @JsonKey(fromJson: RevFromJsonString, toJson: RevToJsonString)
  final Rev rev;
  final String status;
  RevsInfo({
    required this.rev,
    required this.status,
  });
  factory RevsInfo.fromJson(Map<String, dynamic> json) =>
      _$RevsInfoFromJson(json);
  Map<String, dynamic> toJson() => _$RevsInfoToJson(this);
}
