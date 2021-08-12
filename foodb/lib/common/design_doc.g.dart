// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_doc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignDoc _$DesignDocFromJson(Map<String, dynamic> json) {
  return DesignDoc(
    language: json['language'] as String,
    views: (json['views'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, DesignDocView.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$DesignDocToJson(DesignDoc instance) => <String, dynamic>{
      'language': instance.language,
      'views': instance.views,
    };

DesignDocView _$DesignDocViewFromJson(Map<String, dynamic> json) {
  return DesignDocView(
    map: ViewMapper.fromJson(json['map'] as Map<String, dynamic>),
    reduce: json['reduce'] as String,
    options: ViewOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$DesignDocViewToJson(DesignDocView instance) =>
    <String, dynamic>{
      'map': instance.map,
      'reduce': instance.reduce,
      'options': instance.options,
    };

ViewMapper _$ViewMapperFromJson(Map<String, dynamic> json) {
  return ViewMapper(
    fields: Map<String, String>.from(json['fields'] as Map),
    partialFilterSelector:
        (json['partial_filter_sector'] as Map<String, dynamic>?)?.map(
      (k, e) => MapEntry(k, e as String),
    ),
  );
}

Map<String, dynamic> _$ViewMapperToJson(ViewMapper instance) =>
    <String, dynamic>{
      'fields': instance.fields,
      'partial_filter_sector': instance.partialFilterSelector,
    };

ViewOptions _$ViewOptionsFromJson(Map<String, dynamic> json) {
  return ViewOptions(
    def: ViewOptionsDef.fromJson(json['def'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$ViewOptionsToJson(ViewOptions instance) =>
    <String, dynamic>{
      'def': instance.def,
    };

ViewOptionsDef _$ViewOptionsDefFromJson(Map<String, dynamic> json) {
  return ViewOptionsDef(
    fields: (json['fields'] as List<dynamic>).map((e) => e as String).toList(),
  );
}

Map<String, dynamic> _$ViewOptionsDefToJson(ViewOptionsDef instance) =>
    <String, dynamic>{
      'fields': instance.fields,
    };
