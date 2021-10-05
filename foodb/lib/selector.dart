//for _index and _find func
import 'package:collection/collection.dart';
import 'package:foodb/exception.dart';

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
    try {
      if (value is List || value is Map) {
        return DeepCollectionEquality().equals(value, expected);
      }
      return value == expected;
    } catch (e) {
      return false;
    }
  }
}

class NotEqualOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    try {
      if (value is List || value is Map) {
        return !DeepCollectionEquality().equals(value, expected);
      }
      return value != expected;
    } catch (e) {
      return true;
    }
  }
}

class GreaterThanOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String && expected is String) {
      return value.compareTo(expected) > 0;
    } else if (value is num && expected is num) {
      return value.compareTo(expected) > 0;
    } else if (value is String && expected is num) {
      return true;
    } else if (value is num && expected is String) {
      return false;
    }
    return false;
  }
}

class GreaterThanOrEqualOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String && expected is String) {
      return value.compareTo(expected) >= 0;
    } else if (value is num && expected is num) {
      return value.compareTo(expected) >= 0;
    } else if (value is String && expected is num) {
      return true;
    } else if (value is num && expected is String) {
      return false;
    }
    return false;
  }
}

class LessThanOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String && expected is String) {
      return value.compareTo(expected) < 0;
    } else if (value is num && expected is num) {
      return value.compareTo(expected) < 0;
    } else if (value is String && expected is num) {
      return false;
    } else if (value is num && expected is String) {
      return true;
    }
    return false;
  }
}

class LessThanOrEqualOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String && expected is String) {
      return value.compareTo(expected) <= 0;
    } else if (value is num && expected is num) {
      return value.compareTo(expected) <= 0;
    } else if (value is String && expected is num) {
      return false;
    } else if (value is num && expected is String) {
      return true;
    }
    return false;
  }
}

class ExistsOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is bool) {
      return (value != null) == expected;
    }
    throw AdapterException(
        error: "bad_arg",
        reason: "Bad argument for operator \$exists: $expected");
  }
}

class TypeOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String) {
      return expected == "string";
    } else if (value is num) {
      return expected == "number";
    } else if (value is bool) {
      return expected == "boolean";
    } else if (value is List) {
      return expected == "array";
    } else if (value is Map) {
      return expected == "object";
    } else if (value == null) {
      return expected == "null";
    }
    return false;
  }
}

class InOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is List) {
      if (value is Map || value is List) {
        for (var object in expected) {
          if (DeepCollectionEquality().equals(object, value)) {
            return true;
          }
        }
        return false;
      }
      return expected.contains(value);
    }
    throw AdapterException(
        error: "bad_arg", reason: "Bad argument for operator \$in: $expected");
  }
}

class NotInOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is List) {
      if (value is Map || value is List) {
        for (var object in expected) {
          if (DeepCollectionEquality().equals(object, value)) {
            return false;
          }
        }
        return true;
      }
      return !expected.contains(value);
    }
    throw AdapterException(
        error: "bad_arg", reason: "Bad argument for operator \$nin: $expected");
  }
}

class SizeOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is int) {
      if (value is List) {
        return value.length == expected;
      }
      return false;
    }
    throw AdapterException(
        error: "bad_arg",
        reason: "Bad argument for operator \$size: $expected");
  }
}

class ModOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is List<int> && expected.length == 2) {
      if (value is int) {
        return value % expected[0] == expected[1];
      }
      return false;
    }
    throw AdapterException(
        error: "bad_arg", reason: "Bad argument for operator \$mod: $expected");
  }
}

class RegexOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is String) {
      if (value is String) {
        return RegExp(expected).hasMatch(value);
      }
    }
   throw AdapterException(error: "invalid_operator",reason: "Invalid operator: \$regex");
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

class OrOperator extends CombinationOperator {
  @override
  bool combine(bool a, bool b) {
    return a || b;
  }
}

getOperator(keyword) {
  switch (keyword) {
  }
}
