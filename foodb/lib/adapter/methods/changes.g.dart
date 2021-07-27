// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangeResultRev _$ChangeResultRevFromJson(Map<String, dynamic> json) {
  return ChangeResultRev(
    rev: json['rev'] as String,
  );
}

Map<String, dynamic> _$ChangeResultRevToJson(ChangeResultRev instance) =>
    <String, dynamic>{
      'rev': instance.rev,
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
      'results': instance.results,
    };

ChangeRequestBody _$ChangeRequestBodyFromJson(Map<String, dynamic> json) {
  return ChangeRequestBody(
    docIds: (json['doc_ids'] as List<dynamic>).map((e) => e as String).toList(),
  );
}

Map<String, dynamic> _$ChangeRequestBodyToJson(ChangeRequestBody instance) =>
    <String, dynamic>{
      'doc_ids': instance.docIds,
    };
