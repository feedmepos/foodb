import 'package:json_annotation/json_annotation.dart';

part 'purge.g.dart';

@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class PurgeResponse {
  @JsonKey(name: 'purge_seq')
  String? purgeSeq;

  @JsonKey(name: 'purged')
  Map<String, List<String>>? purged;

  PurgeResponse({
    required this.purgeSeq,
    required this.purged,
  });

  factory PurgeResponse.fromJson(Map<String, dynamic> json) =>
      _$PurgeResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PurgeResponseToJson(this);
}
