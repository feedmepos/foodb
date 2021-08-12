import 'package:json_annotation/json_annotation.dart';

part 'design_doc.g.dart';

@JsonSerializable()
class DesignDoc {
  String language;
  Map<String, DesignDocView> views;

  DesignDoc({required this.language, required this.views});

  factory DesignDoc.fromJson(Map<String, dynamic> json) =>
      _$DesignDocFromJson(json);
  Map<String, dynamic> toJson() => _$DesignDocToJson(this);
}

@JsonSerializable()
class DesignDocView {
  ViewMapper map;
  String reduce;
  ViewOptions options;

  DesignDocView(
      {required this.map, required this.reduce, required this.options});

  factory DesignDocView.fromJson(Map<String, dynamic> json) =>
      _$DesignDocViewFromJson(json);
  Map<String, dynamic> toJson() => _$DesignDocViewToJson(this);
}

@JsonSerializable()
class ViewMapper {
  Map<String, String> fields;

  @JsonKey(name: "partial_filter_sector")
  Map<String, String>? partialFilterSelector;

  ViewMapper({required this.fields, this.partialFilterSelector});

  factory ViewMapper.fromJson(Map<String, dynamic> json) =>
      _$ViewMapperFromJson(json);
  Map<String, dynamic> toJson() => _$ViewMapperToJson(this);
}

@JsonSerializable()
class ViewOptions {
  ViewOptionsDef def;
  ViewOptions({required this.def});

  factory ViewOptions.fromJson(Map<String, dynamic> json) =>
      _$ViewOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$ViewOptionsToJson(this);
}

@JsonSerializable()
class ViewOptionsDef {
  List<String> fields;
  ViewOptionsDef({required this.fields});

  factory ViewOptionsDef.fromJson(Map<String, dynamic> json) =>
      _$ViewOptionsDefFromJson(json);
  Map<String, dynamic> toJson() => _$ViewOptionsDefToJson(this);
}
