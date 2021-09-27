import 'package:foodb/common/rev.dart';
import 'package:json_annotation/json_annotation.dart';

part 'revs_diff.g.dart';

@JsonSerializable()
class RevsDiff {
  @JsonKey(fromJson: ListOfRevFromJsonString, toJson: ListOfRevFromJsonString)
  List<Rev> missing;
  @JsonKey(name: 'possible_ancestors')
  List<String>? possibleAncestors;
  RevsDiff({
    required this.missing,
    this.possibleAncestors,
  });

  factory RevsDiff.fromJson(Map<String, dynamic> json) =>
      _$RevsDiffFromJson(json);
  Map<String, dynamic> toJson() => _$RevsDiffToJson(this);
}
