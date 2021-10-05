//for _index and _find func
import 'package:collection/equality.dart';

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
    } else if (value is int && expected is int) {
      return value.compareTo(expected) > 0;
    } else if (value is String && expected is int) {
      return true;
    } else if (value is int && expected is String) {
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
    } else if (value is int && expected is int) {
      return value.compareTo(expected) >= 0;
    } else if (value is String && expected is int) {
      return true;
    } else if (value is int && expected is String) {
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
    } else if (value is int && expected is int) {
      return value.compareTo(expected) < 0;
    } else if (value is String && expected is int) {
      return false;
    } else if (value is int && expected is String) {
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
    } else if (value is int && expected is int) {
      return value.compareTo(expected) <= 0;
    } else if (value is String && expected is int) {
      return false;
    } else if (value is int && expected is String) {
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
    return (value != null) == expected;
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
      return expected.contains(value);
    }
    return false;
  }
}

class NotInOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (expected is List) {
      return !expected.contains(value);
    }
    return false;
  }
}

class SizeOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is List) {
      return value.length==expected;
    }
    return false;
  }
}

class ModOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is int && expected is List && expected.length==2) {
      return value%expected[0]==expected[1];
    }
    return false;
  }
}

class RegexOperator extends ConditionOperator {
  dynamic value;
  dynamic expected;

  @override
  bool evaluate() {
    if (value is String && expected is String) {
      return RegExp("${expected}\$").hasMatch(value);
    }
    return false;
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
