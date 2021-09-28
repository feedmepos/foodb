// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_sequence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateSequence _$UpdateSequenceFromJson(Map<String, dynamic> json) {
  return UpdateSequence(
    id: json['id'] as String,
    winnerRev: RevFromJsonString(json['winnerRev'] as String?),
    allLeafRev: ListOfRevFromJsonString(json['allLeafRev'] as List),
  );
}

Map<String, dynamic> _$UpdateSequenceToJson(UpdateSequence instance) =>
    <String, dynamic>{
      'id': instance.id,
      'winnerRev': RevToJsonString(instance.winnerRev),
      'allLeafRev': ListOfRevToJsonString(instance.allLeafRev),
    };
