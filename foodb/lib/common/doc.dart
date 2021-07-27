import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'doc.g.dart';

@JsonSerializable()
@immutable
class Doc {
  @JsonKey(name: '_id')
  final String id;

  @JsonKey(name: '_rev')
  final String rev;

  @JsonKey(name: '_deleted')
  final bool? deleted;

  @JsonKey(name: '_revisions')
  final Revisions? revisions;

  final Map<String, dynamic>? json;

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
    required this.rev,
    this.deleted,
    this.revisions,
    this.json,
    this.attachments,
    this.conflicts,
    this.deletedConflicts,
    this.revsInfo,
    this.localSeq,
  });

  factory Doc.fromJson(Map<String, dynamic> json) => _$DocFromJson(json);
  Map<String, dynamic> toJson() => _$DocToJson(this);
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
