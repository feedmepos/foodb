import 'package:test/test.dart';
import 'package:foodb/src/exception.dart';
import 'package:foodb/src/selector.dart';

class SelectorBuilder {
  var value;
  SelectorBuilder();

  Operator fromJson(Map<String, dynamic> json) {
    List<Operator> subList = [];
    json.entries.forEach((element) {
      subList.add(DFS(json: Map.fromEntries([element])));
    });
    if (subList.length > 1) {
      this.value = AndOperator(operators: subList);
    } else {
      this.value = subList.first;
    }

    return this.value;
  }

  Operator DFS({String? key, required Map<String, dynamic> json}) {
    for (MapEntry<String, dynamic> entry in json.entries) {
      final operator = getOperator(entry.key);
      if (operator is CombinationOperator) {
        List<Operator> subList = [];
        entry.value.forEach((e) {
          subList.add(DFS(key: key, json: e));
        });
        operator.operators = subList;
        return operator;
      } else if (operator == null) {
        List<Operator> subList = [];
        print(entry.value);
        entry.value.forEach((operatorStr, arg) {
          final subOperator =
              getOperator(operatorStr, key: entry.key, expected: arg);
          if (subOperator is ConditionOperator) {
            subList.add(subOperator);
          } else if (subOperator is CombinationOperator) {
            subList.add(DFS(key: entry.key, json: {operatorStr: arg}));
          } else if (subOperator == null) {
            if(arg is Map<String,dynamic>){
            print(arg.runtimeType);
              subList.add(nestedOperator(
                  "${key != null ? "$key." : ""}${entry.key}.${operatorStr}",
                  arg));
            } 
            else {
              throw AdapterException(error: 'Invalid Selector Format');
            }
          }
        });
        if (subList.length > 1) {
          return AndOperator(operators: subList);
        } else {
          return subList.first;
        }
      } else {
        throw AdapterException(error: "Invalid Format of Selector");
      }
    }

    return this.value;
  }

  nestedOperator(String nestedKey, Map<String,dynamic> value) {
    List<Operator> operators = [];
    value.forEach((key, value) {
      final operator = getOperator(key, key: nestedKey, expected: value);
      if (operator is Operator) {
        operators.add(DFS(json: {
          nestedKey: {key: value}
        }));
      } else {
        operators.add(nestedOperator("$nestedKey.$key", value));
      }
    });

    if (operators.length > 1) {
      return AndOperator(operators: operators);
    }
    return operators.first;
  }
}

void main() {
  group('test nested fields', () {
    test('check _nestedOperator()', () {
      SelectorBuilder builder = new SelectorBuilder();
      Operator operator = builder.nestedOperator("name", {
        "last": {
          "name": {"\$eq": "foo"}
        },
        "first": {
          "name": {"\$eq": "zq"}
        }
      });
      print(operator.toJson());
      expect(
          operator.toJson(),
          equals({
            "\$and": [
              {
                "name.last.name": {"\$eq": "foo"}
              },
              {
                "name.first.name": {"\$eq": "zq"}
              }
            ]
          }));
    });
    test('check with andOperator', () {
      SelectorBuilder builder = new SelectorBuilder();
      builder.fromJson({
        "name": {
          "\$and": [
            {
              "last": {
                "name": {"\$eq": "foo"}
              }
            },
            {
              "first": {
                "name": {"\$eq": "zq"}
              }
            }
          ]
        }
      });
      print(builder.value.toJson());
      expect(
          builder.value.toJson(),
          equals({
            "\$and": [
              {
                "name.last.name": {"\$eq": "foo"}
              },
              {
                "name.first.name": {"\$eq": "zq"}
              }
            ]
          }));
    });
  });
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
