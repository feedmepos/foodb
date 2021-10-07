import 'package:json_annotation/json_annotation.dart';

class DesignDoc {
  String? language;
  Map<String, AbstracDesignDocView> views;

  DesignDoc({this.language, required this.views});

  factory DesignDoc.fromJson(Map<String, dynamic> json) => DesignDoc(
        language: json['language'] as String,
        views: (json['views'] as Map<String, dynamic>).map(
          (k, e) => MapEntry(
              k,
              json['language'] == 'query'
                  ? AbstracDesignDocView.QueryDesignDocView(
                      map: QueryViewMapper.fromJson(e['map']),
                      reduce: e['reduce'],
                      options: QueryViewOptions.fromJson(e['options']))
                  : AbstracDesignDocView.JSDesignDocView(map: e['map'])),
        ),
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'language': language,
        'views':
            Map.fromIterables(views.keys, views.values.map((e) => e.toJson()))
      };
}

abstract class AbstracDesignDocView {
  AbstracDesignDocView();

  factory AbstracDesignDocView.JSDesignDocView(
      {required String map, String reduce}) = JSDesignDocView;

  factory AbstracDesignDocView.QueryDesignDocView(
      {required QueryViewMapper map,
      required String reduce,
      required QueryViewOptions options}) = QueryDesignDocView;

  factory AbstracDesignDocView.AllDocDesignDocView() = AllDocDesignDocView;

  Map<String, dynamic> toJson();
}

class JSDesignDocView extends AbstracDesignDocView {
  String map;
  String? reduce;
  JSDesignDocView({required this.map, this.reduce});

  Map<String, dynamic> toJson() => {
        "map": map,
        "reduce": reduce,
      };
}

class QueryDesignDocView extends AbstracDesignDocView {
  QueryViewMapper map;
  String reduce;
  QueryViewOptions options;

  QueryDesignDocView(
      {required this.map, required this.reduce, required this.options});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'map': map.toJson(),
        'reduce': reduce,
        'options': options.toJson(),
      };
}

class AllDocDesignDocView extends AbstracDesignDocView {
  AllDocDesignDocView();

  Map<String, dynamic> toJson() => {};
}

class QueryViewMapper {
  Map<String, String> fields;

  @JsonKey(name: "partial_filter_sector")
  Map<String, dynamic>? partialFilterSelector;

  QueryViewMapper({required this.fields, this.partialFilterSelector});

  factory QueryViewMapper.fromJson(Map<String, dynamic> json) =>
      QueryViewMapper(
        fields: Map<String, String>.from(json['fields'] as Map),
        partialFilterSelector:
            (json['partial_filter_sector'] as Map<String, dynamic>?)?.map(
          (k, e) => MapEntry(k, e),
        ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fields': fields,
        'partial_filter_sector': partialFilterSelector,
      };
}

class QueryViewOptions {
  QueryViewOptionsDef def;

  QueryViewOptions({required this.def});

  factory QueryViewOptions.fromJson(Map<String, dynamic> json) =>
      QueryViewOptions(
        def: QueryViewOptionsDef.fromJson(json['def'] as Map<String, dynamic>),
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'def': def.toJson(),
      };
}

class QueryViewOptionsDef {
  List<String> fields;

  // TODO
  // @JsonKey(name: "partial_filter_sector")
  // Map<String, dynamic>? partialFilterSelector;

  QueryViewOptionsDef({required this.fields});

  factory QueryViewOptionsDef.fromJson(Map<String, dynamic> json) =>
      QueryViewOptionsDef(
        fields:
            (json['fields'] as List<dynamic>).map((e) => e as String).toList(),
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'fields': fields,
      };
}
