import 'package:json_annotation/json_annotation.dart';

part 'update_sequence.g.dart';

@JsonSerializable()
class UpdateSequence {
  String seq;
  String id;
  String winnerRev;
  List<String> allLeafRev;
  UpdateSequence({
    required this.seq,
    required this.id,
    required this.winnerRev,
    required this.allLeafRev,
  });

  factory UpdateSequence.fromJson(Map<String, dynamic> json) =>
      _$UpdateSequenceFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateSequenceToJson(this);
}
