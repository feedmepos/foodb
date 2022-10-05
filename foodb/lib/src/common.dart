import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

part 'common.g.dart';

ListOfRevFromJsonString(List<dynamic> strs) {
  return strs.map<Rev>((e) => RevFromJsonString(e)).toList();
}

ListOfRevToJsonString(List<Rev> strs) {
  return strs.map<String>((e) => RevToJsonString(e)).toList();
}

OptionalListOfRevFromJsonString(List<dynamic>? strs) {
  return strs?.map<Rev>((e) => RevFromJsonString(e)).toList();
}

OptionalListOfRevToJsonString(List<Rev>? strs) {
  return strs?.map<String>((e) => RevToJsonString(e)).toList();
}

RevFromJsonString(String? str) {
  if (str == null) {
    return null;
  }
  var splitted = str.split('-');
  return Rev(index: int.parse(splitted[0]), md5: splitted[1]);
}

RevToJsonString(Rev? instance) {
  if (instance == null) {
    return null;
  }
  return '${instance.index}-${instance.md5}';
}

class Rev {
  int index;
  String md5;
  Rev({
    required this.index,
    required this.md5,
  });

  Rev increase(Map<String, dynamic> json) {
    return Rev(
        index: index + 1,
        md5: crypto.md5
            .convert(utf8
                .encode(index.toString() + md5.toString() + jsonEncode(json)))
            .toString());
  }

  @override
  String toString() {
    return RevToJsonString(this);
  }

  factory Rev.fromString(String str) {
    return RevFromJsonString(str);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rev && other.index == index && other.md5 == md5;
  }

  @override
  int get hashCode => index.hashCode ^ md5.hashCode;

  int compareTo(Rev other) {
    final indexCmp = this.index.compareTo(other.index);
    if (indexCmp != 0) return indexCmp;
    return this.md5.compareTo(other.md5);
  }
}

//@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class Doc<T> {
  final String id;
  final Rev? rev;
  final bool? deleted;
  final Revisions? revisions;
  final T model;
  final Object? attachments;
  final List<Rev>? conflicts;
  final List<Rev>? deletedConflicts;
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
          ?.map((e) => RevFromJsonString(e) as Rev)
          .toList(),
      revsInfo: (json['_revs_info'] as List<dynamic>?)
          ?.map((e) => RevsInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      localSeq: json['_local_seq'] as String?,
    );
  }
  Map<String, dynamic> toJson(
    Object? Function(T value) toJsonT, {
    fullMeta = false,
  }) {
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

    if (fullMeta) {
      map.addAll({
        '_attachments': null,
        '_conflicts': conflicts?.map((e) => e.toString()).toList(),
        '_deleted_conflicts':
            deletedConflicts?.map((e) => e.toString()).toList(),
        '_revs_info': revsInfo?.map((e) => e.toJson()).toList(),
        '_local_seq': localSeq
      });
    }

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

@JsonSerializable(explicitToJson: true)
class ReplicationLog {
  List<History> history;

  @JsonKey(name: 'replication_id_version')
  int replicationIdVersion;

  @JsonKey(name: 'session_id')
  String sessionId;

  @JsonKey(name: 'source_last_seq')
  String sourceLastSeq;

  ReplicationLog({
    required this.history,
    required this.replicationIdVersion,
    required this.sessionId,
    required this.sourceLastSeq,
  });

  factory ReplicationLog.fromJson(Map<String, dynamic> json) =>
      _$ReplicationLogFromJson(json);
  Map<String, dynamic> toJson() => _$ReplicationLogToJson(this);
}

@JsonSerializable()
class History {
  @JsonKey(name: 'session_id')
  String sessionId;

  @JsonKey(name: 'start_time')
  String startTime;

  @JsonKey(name: 'end_time')
  String endTime;

  @JsonKey(name: 'recorded_seq')
  String recordedSeq;

  History({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.recordedSeq,
  });

  factory History.fromJson(Map<String, dynamic> json) =>
      _$HistoryFromJson(json);
  Map<String, dynamic> toJson() => _$HistoryToJson(this);
}
