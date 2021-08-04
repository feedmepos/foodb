// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revs_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevsDiff _$RevsDiffFromJson(Map<String, dynamic> json) {
  return RevsDiff(
    missing:
        (json['missing'] as List<dynamic>).map((e) => e as String).toList(),
    possibleAncestors: (json['possible_ancestors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
  );
}

Map<String, dynamic> _$RevsDiffToJson(RevsDiff instance) => <String, dynamic>{
      'missing': instance.missing,
      'possible_ancestors': instance.possibleAncestors,
    };
