import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'revs_diff.g.dart';

@JsonSerializable()
class RevsDiff {
<<<<<<< HEAD
  @JsonKey(fromJson: ListOfRevFromJsonString, toJson: ListOfRevToJsonString)
  List<Rev> missing;

  @JsonKey(name: 'possible_ancestors',fromJson: OptionalListOfRevFromJsonString, toJson: OptionalListOfRevToJsonString)
  List<Rev>? possibleAncestors;
=======
  @JsonKey(fromJson: ListOfRevFromJsonString, toJson: ListOfRevFromJsonString)
  List<Rev> missing;
  @JsonKey(name: 'possible_ancestors')
  List<String>? possibleAncestors;
>>>>>>> c1eba40... WIP, clean up
  RevsDiff({
    required this.missing,
    this.possibleAncestors,
  });

  factory RevsDiff.fromJson(Map<String, dynamic> json) =>
      _$RevsDiffFromJson(json);
  Map<String, dynamic> toJson() => _$RevsDiffToJson(this);
}
