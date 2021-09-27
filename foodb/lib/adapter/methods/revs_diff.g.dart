// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revs_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevsDiff _$RevsDiffFromJson(Map<String, dynamic> json) {
  return RevsDiff(
    missing: ListOfRevFromJsonString(json['missing'] as List),
<<<<<<< HEAD
    possibleAncestors:
        OptionalListOfRevFromJsonString(json['possible_ancestors'] as List?),
=======
    possibleAncestors: (json['possible_ancestors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
>>>>>>> c1eba40... WIP, clean up
  );
}

Map<String, dynamic> _$RevsDiffToJson(RevsDiff instance) => <String, dynamic>{
<<<<<<< HEAD
      'missing': ListOfRevToJsonString(instance.missing),
      'possible_ancestors':
          OptionalListOfRevToJsonString(instance.possibleAncestors),
=======
      'missing': ListOfRevFromJsonString(instance.missing),
      'possible_ancestors': instance.possibleAncestors,
>>>>>>> c1eba40... WIP, clean up
    };
