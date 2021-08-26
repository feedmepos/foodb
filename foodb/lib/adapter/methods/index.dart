import 'package:foodb/common/doc_history.dart';
import 'package:json_annotation/json_annotation.dart';

part 'index.g.dart';

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

@JsonSerializable()
class IndexResponse {
  String result;
  String id;
  String name;

  IndexResponse({required this.result, required this.id, required this.name});

  factory IndexResponse.fromJson(Map<String, dynamic> json) =>
      _$IndexResponseFromJson(json);
  Map<String, dynamic> toJson() => _$IndexResponseToJson(this);
}
