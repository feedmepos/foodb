// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revs_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevsDiff _$RevsDiffFromJson(Map<String, dynamic> json) {
  return RevsDiff(
    missing: ListOfRevFromJsonString(json['missing'] as List),
    possibleAncestors: (json['possible_ancestors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
  );
}

Map<String, dynamic> _$RevsDiffToJson(RevsDiff instance) => <String, dynamic>{
      'missing': ListOfRevToJsonString(instance.missing),
      'possible_ancestors': instance.possibleAncestors,
    };
