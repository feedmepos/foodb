import 'package:json_annotation/json_annotation.dart';

part 'server.g.dart';

@JsonSerializable()
class GetServerInfoResponse {
  @JsonKey(name: 'uuid')
  String uuid;
  @JsonKey(name: 'version')
  String version;
  GetServerInfoResponse({
    required this.uuid,
    required this.version,
  });

  factory GetServerInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$GetServerInfoResponseFromJson(json);
  Map<String, dynamic> toJson() => _$GetServerInfoResponseToJson(this);
}
