import 'package:json_annotation/json_annotation.dart';

part 'design_doc.g.dart';

//for _index and _find func
class Operator<T> {
  final String operator;
  late final String key;
  late final T value;

  Operator({required this.operator});

  MapEntry<String, dynamic> toJson() {
    return MapEntry(key, {operator: value});
  }
}

class CombinationOperator {
  static final and = "\$and";
  static final or = "\$or";

  static get andOp => Operator<List<dynamic>>(operator: and);
  static get orOp => Operator<List<dynamic>>(operator: or);
  static get notOp => Operator<Map<String, dynamic>>(operator: "\$not");
  static get norOp => Operator<List<dynamic>>(operator: "\$nor");
  static get allOp => Operator<List<dynamic>>(operator: "\$all");
  static get elemMatchOp =>
      Operator<Map<String, dynamic>>(operator: "\$elemMatch");
  static get allMatchOp =>
      Operator<Map<String, dynamic>>(operator: "\$allMatch");
  static get keyMapMatchOp =>
      Operator<Map<String, dynamic>>(operator: "\$keyMapMatch");
}

class IndexConditionOperator {
  static const lessThan = "\$lt";
  static const lessThanOrEqual = "\$lte";
  static const equal = "\$eq";
  static const notEqual = "\$ne";

  //operator function for find
  static get lessThanOperator => Operator<dynamic>(operator: lessThan);
  static get lessThanOrEqualOperator =>
      Operator<dynamic>(operator: lessThanOrEqual);
  static get equalOperator => Operator<dynamic>(operator: equal);
  static get notEqualOperator => Operator<dynamic>(operator: notEqual);
  static get greaterThanOrEqualOperator => Operator<dynamic>(operator: "\$gte");
  static get greaterThanOperator => Operator<dynamic>(operator: "\$gt");
  static get existsOperator => Operator<bool>(operator: "\$exits");
  static get typeOperator => Operator<String>(operator: "\$type");
  static get existsInListOperator => Operator<List<dynamic>>(operator: "\$in");
  static get notExistsInListOperator =>
      Operator<List<dynamic>>(operator: "\$nin");
  static get sizeOperator => Operator<int>(operator: "\$size");
  static get modOperator => Operator<List<int>>(operator: "\$mod");
  static get regexOperator => Operator<String>(operator: "\$regex");

  static Function(dynamic) conditionalCheck(String operator, dynamic argument) {
    switch (operator) {
      case lessThan:
        return (value) => value < argument;
      case lessThanOrEqual:
        return (value) => value <= argument;
      case equal:
        return (value) => value == argument;
      case notEqual:
        return (value) => value != argument;
      default:
        return (value) => false;
    }
  }
}

class PartialFilterSelector {
  Map<String, dynamic> value = {};
  Set<String> keys = {};

  Map<String, dynamic> generateSelector(Map<String, dynamic> json) {
    List<dynamic> subList = [];
    json.entries.forEach((element) {
      subList.add(_rebuildDFS(Map.fromEntries([element])));
    });
    if (subList.length > 1)
      this.value = {CombinationOperator.and: subList};
    else {
      this.value = subList.first;
    }
    return this.value;
  }

  Map<String, dynamic> _rebuildDFS(Map<String, dynamic> json) {
    for (MapEntry<String, dynamic> entry in json.entries) {
      if (entry.key == CombinationOperator.and) {
        List<dynamic> subList = [];
        entry.value.forEach((e) {
          subList.add(_rebuildDFS(e));
        });
        if (this.value.length > 1) {
          this.value = {
            CombinationOperator.and: [
              value,
              {CombinationOperator.and: subList}
            ]
          };
        } else {
          this.value = {CombinationOperator.and: subList};
        }

        return this.value;
      } else {
        if (entry.value.length > 1) {
          List<dynamic> subList = [];
          entry.value.forEach((operator, arg) {
            this.keys.add(entry.key);
            subList.add({
              entry.key: {operator: arg}
            });
          });

          return <String, dynamic>{CombinationOperator.and: subList};
        }
        this.keys.add(entry.key);
        return {entry.key: entry.value};
      }
    }
    return this.value;
  }
}

class SelectorDecomposer {
  Map<String, dynamic> value = {};
  Set<String> keys = {};

  Map<String, dynamic> decomposeSelector(Map<String, dynamic> json) {
    return value;
  }

  Map<String, dynamic> _decomposeDFS(Map<String, dynamic> json) {
    return value;
  }
}

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
