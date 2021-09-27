// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revs_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevsDiff _$RevsDiffFromJson(Map<String, dynamic> json) {
  return RevsDiff(
    missing: ListOfRevFromJsonString(json['missing'] as List),
    possibleAncestors:
        OptionalListOfRevFromJsonString(json['possible_ancestors'] as List?),
  );
}

Map<String, dynamic> _$RevsDiffToJson(RevsDiff instance) => <String, dynamic>{
      'missing': ListOfRevToJsonString(instance.missing),
      'possible_ancestors':
          OptionalListOfRevToJsonString(instance.possibleAncestors),
    };
