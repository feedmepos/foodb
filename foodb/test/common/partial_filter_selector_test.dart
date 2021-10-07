import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/exception.dart';
import 'package:foodb/selector.dart';

class SelectorBuilder {
  var value;
  SelectorBuilder();

  Operator fromJson(Map<String, dynamic> json) {
    List<Operator> subList = [];
    json.entries.forEach((element) {
      subList.add(DFS(Map.fromEntries([element])));
    });
    if (subList.length > 1) {
      this.value = AndOperator(operators: subList);
    } else {
      this.value = subList.first;
    }

    return this.value;
  }

  Operator DFS(Map<String, dynamic> json) {
    for (MapEntry<String, dynamic> entry in json.entries) {
      final operator = getOperator(entry.key);
      if (operator is CombinationOperator) {
        List<Operator> subList = [];
        entry.value.forEach((e) {
          subList.add(DFS(e));
        });
        operator.operators = subList;
        this.value = operator;
        return value;
      } else if (operator == null) {
        List<Operator> subList = [];
        entry.value.forEach((operatorStr, arg) {
          final operator =
              getOperator(operatorStr, key: entry.key, expected: arg);
          if (operator is ConditionOperator) {
            subList.add(operator);
          } else {
            throw AdapterException(error: "Invalid Format of Selector");
          }
        });
        if (subList.length > 1) {
          return AndOperator(operators: subList);
        } else {
          return subList[0];
        }
      } else {
        throw AdapterException(error: "Invalid Format of Selector");
      }
    }

    return this.value;
  }
}

void main() {
  test('test DFS with multiple operator within one entry', () {
    SelectorBuilder builder = new SelectorBuilder();
    final operator = builder.fromJson({
      "no": {"\$gt": 100, "\$lt": 300},
      "name": {"\$gt": 100, "\$lt": 300}
    });
    expect(operator.toJson(), {
      '\$and': [
        {
          '\$and': [
            {
              'no': {'\$gt': 100}
            },
            {
              'no': {'\$lt': 300}
            }
          ]
        },
        {
          '\$and': [
            {
              'name': {'\$gt': 100}
            },
            {
              'name': {'\$lt': 300}
            }
          ]
        }
      ]
    });
    expect(builder.value.evaluate({"no": 200, "name": 200}), true);
    expect(builder.value.evaluate({"no": 300, "name": 300}), false);
  });
  test("test DFS with multiple and", () {
    SelectorBuilder builder = new SelectorBuilder();
    builder.fromJson({
      "\$and": [
        {
          "\$and": [
            {
              "no": {"\$gt": 100}
            },
            {
              "no": {"\$lt": 300}
            }
          ]
        },
        {
          "\$and": [
            {
              "name": {"\$gt": 100}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        }
      ]
    });

    expect(builder.value.evaluate({"name": 200, "no": 200}), true);
    expect(builder.value.evaluate({"name": 300, "no": 300}), false);
    print(builder.value.toJson());
    expect(builder.value.toJson(), {
      "\$and": [
        {
          "\$and": [
            {
              "no": {"\$gt": 100}
            },
            {
              "no": {"\$lt": 300}
            }
          ]
        },
        {
          "\$and": [
            {
              "name": {"\$gt": 100}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        }
      ]
    });
  });
  test("triple nested and", () {
    SelectorBuilder builder = new SelectorBuilder();
    builder.fromJson({
      "\$and": [
        {
          "\$and": [
            {
              "\$and": [
                {
                  "no": {"\$gt": 100}
                },
                {
                  "no": {"\$lt": 300}
                }
              ]
            },
            {
              "name": {"\$gt": 100}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        },
        {
          "\$and": [
            {
              "name": {"\$gt": 100}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        }
      ]
    });

    expect(builder.value.evaluate({"name": 200, "no": 200}), true);
    expect(builder.value.evaluate({"name": 300, "no": 300}), false);
    print(builder.value.toJson());
    expect(builder.value.toJson(), {
      "\$and": [
        {
          "\$and": [
            {
              "\$and": [
                {
                  "no": {"\$gt": 100}
                },
                {
                  "no": {"\$lt": 300}
                }
              ]
            },
            {
              "name": {"\$gt": 100}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        },
        {
          "\$and": [
            {
              "name": {"\$gt": 100}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        }
      ]
    });
  });
  test('test DFS with complex structure', () {
    SelectorBuilder builder = new SelectorBuilder();
    Operator value = builder.fromJson({
      "\$and": [
        {
          "no": {"\$gt": 100, "\$lt": 300}
        },
        {
          "name": {"\$gt": 300}
        }
      ],
      "name": {"\$eq": 100}
    });

    print(builder.value.toJson());
    expect(
        value.toJson(),
        equals({
          "\$and": [
            {
              "\$and": [
                {
                  "\$and": [
                    {
                      "no": {"\$gt": 100}
                    },
                    {
                      "no": {"\$lt": 300}
                    }
                  ]
                },
                {
                  "name": {"\$gt": 300}
                }
              ]
            },
            {
              "name": {"\$eq": 100}
            }
          ]
        }));
  });
}
