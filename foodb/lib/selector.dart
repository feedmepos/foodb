//for _index and _find func
abstract class Operator {
  late String operator;
  bool evaluate();
}

abstract class ConditionOperator extends Operator {}

class EqualOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String && expected is String) {
      return value.compareTo(expected) == 0;
    }
    return true;
  }
}

abstract class CombinationOperator extends Operator {
  List<Operator> operators = [];

  bool combine(bool a, bool b);

  bool evaluate() {
    var result = true;
    for (final o in operators) {
      result = combine(result, o.evaluate());
    }
    return result;
  }
}

class AndOperator extends CombinationOperator {
  @override
  bool combine(bool a, bool b) {
    return a && b;
  }
}

getOperator(keyword) {
  switch (keyword) {
  }
}
