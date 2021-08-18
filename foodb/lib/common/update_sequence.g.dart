// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_sequence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateSequence _$UpdateSequenceFromJson(Map<String, dynamic> json) {
  return UpdateSequence(
    seq: json['seq'] as String,
    id: json['id'] as String,
    winnerRev: json['winnerRev'] as String,
    allLeafRev:
        (json['allLeafRev'] as List<dynamic>).map((e) => e as String).toList(),
  );
}

Map<String, dynamic> _$UpdateSequenceToJson(UpdateSequence instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'id': instance.id,
      'winnerRev': instance.winnerRev,
      'allLeafRev': instance.allLeafRev,
    };
