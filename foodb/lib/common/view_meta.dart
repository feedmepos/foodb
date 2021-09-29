import 'package:json_annotation/json_annotation.dart';

part 'view_meta.g.dart';

@JsonSerializable()
class ViewMeta {
  int lastSeq;

  ViewMeta({required this.lastSeq});

  factory ViewMeta.fromJson(Map<String, dynamic> json) =>
      _$ViewMetaFromJson(json);
  Map<String, dynamic> toJson() => _$ViewMetaToJson(this);
}
