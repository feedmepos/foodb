import 'dart:convert';
import 'package:test/test.dart';
import 'package:foodb/src/exception.dart';
import 'package:foodb/src/selector.dart';

void main() {
  test('and, equal', () {
    final and = AndOperator();
    final equal1 = EqualOperator(key: "1", expected: "a");
    final equal2 = EqualOperator(key: "2", expected: 1);
    final equal3 = EqualOperator(key: "3", expected: [
      "1",
      {1: "a"}
    ]);
    final equal4 = EqualOperator(key: "4", expected: {
      "a": [1, 2]
    });

    and.operators.addAll([equal1, equal2, equal3, equal4]);
    expect(
        and.evaluate({
          "1": "a",
          "2": 1,
          "3": [
            "1",
            {1: "a"}
          ],
          "4": {
            "a": [1, 2]
          }
        }),
        true);
  });
  test('or, not equal', () {
    final or = OrOperator();
    final notEqual1 = NotEqualOperator(key: "test", expected: "a");
    final notEqual2 = NotEqualOperator(key: "test", expected: "b");

    or.operators.addAll([notEqual1, notEqual2]);
    expect(or.evaluate({"test": "b"}), true);
  });
  test('and, not equal', () {
    final and = AndOperator();
    final notEqual1 = NotEqualOperator(key: "1", expected: {
      12: ["b"]
    });
    final notEqual2 = NotEqualOperator(key: "2", expected: [
      {1: 'b'}
    ]);
    and.operators.addAll([notEqual1, notEqual2]);
    expect(
        and.evaluate({
          "1": {
            12: ["a"]
          },
          "2": [
            {1: 'a'}
          ]
        }),
        true);
  });
  test("and,greater than", () {
    final and = AndOperator();
    final greaterThan1 = GreaterThanOperator(key: "1", expected: 0);
    final greaterThan2 = GreaterThanOperator(key: "2", expected: "ayam");

    and.operators.addAll([greaterThan1, greaterThan2]);
    expect(and.evaluate({"1": 1, "2": "nasi lemak"}), true);
  });
  test("and, greater than or equal", () {
    final and = AndOperator();
    final greaterThan1 = GreaterThanOrEqualOperator(key: "1", expected: 100);
    final greaterThan2 = GreaterThanOrEqualOperator(key: "2", expected: "ayam");
    and.operators.addAll([greaterThan1, greaterThan2]);
    expect(and.evaluate({"1": 100, "2": "nasi lemak"}), true);
  });
  test("and, less than", () {
    final and = AndOperator();
    final lessThan1 = LessThanOperator(key: "1", expected: 1);
    final lessThan2 = LessThanOperator(key: "2", expected: "nasi lemak");

    and.operators.addAll([lessThan1, lessThan2]);
    expect(and.evaluate({"1": 0, "2": "ayam"}), true);
  });
  test("and, less than or equal", () {
    final and = AndOperator();
    final lessThan1 = LessThanOrEqualOperator(key: "1", expected: 0);
    final lessThan2 = LessThanOrEqualOperator(key: "2", expected: "nasi lemak");
    and.operators.addAll([lessThan1, lessThan2]);
    expect(and.evaluate({"1": 0, "2": "ayam"}), true);
  });
  test("and, exists", () {
    final and = AndOperator();
    final exists1 = ExistsOperator(key: "1", expected: false);
    final exists2 = ExistsOperator(key: "2", expected: true);
    and.operators.addAll([exists1, exists2]);
    expect(and.evaluate({"1": null, "2": "pedas"}), true);
  });
  test("and, type", () {
    final and = AndOperator();
    final type1 = TypeOperator(key: "1", expected: "string");
    final type2 = TypeOperator(key: "2", expected: "object");
    final type3 = TypeOperator(key: "3", expected: "array");

    and.operators.addAll([type1, type2, type3]);
    expect(and.evaluate({"1": "string", "2": {}, "3": []}), true);
  });
  test("and, in, not in", () {
    final and = AndOperator();
    final type1 = InOperator(key: "1", expected: [
      3,
      {1: 2},
      2
    ]);
    final type2 = InOperator(key: "2", expected: ["c", "b", "a"]);
    final type3 = NotInOperator(key: "3", expected: [
      [1],
      2,
      3
    ]);
    final type4 = NotInOperator(key: "4", expected: ["a", "b", "c"]);

    and.operators.addAll([type1, type2, type3, type4]);
    expect(
        and.evaluate({
          "1": {1: 2},
          "2": "a",
          "3": [1, 2],
          "4": "d"
        }),
        true);
  });
  test("and, size", () {
    final and = AndOperator();
    final size = SizeOperator(key: "1", expected: 3);
    and.operators.addAll([size]);
    expect(
        and.evaluate({
          "1": [1, 2, 3]
        }),
        true);
  });
  test("and, mod", () {
    final and = AndOperator();
    final mod1 = ModOperator(key: "1", expected: [10, 0]);
    final mod2 = ModOperator(key: "2", expected: [3, 1]);
    and.operators.addAll([mod1, mod2]);
    expect(and.evaluate({"1": 100, "2": 10}), true);
  });
  test("and, regex", () {
    final and = AndOperator();
    final regex1 = RegexOperator(key: "1", expected: "^user");
    final regex2 = RegexOperator(key: "2", expected: "^{\".*},?\n?\$");

    and.operators.addAll([regex1, regex2]);
    expect(
        and.evaluate({
          "1": "user_feedme",
          "2": jsonEncode({
            "seq":
                "2-g1AAAACreJzLYWBgYMxgTmGwT84vTc5ISXKA0row2lAPTUQvJbVMr7gsWS85p7S4JLVILyc_OTEnB2gQUyJDHgvDfyDIymBOZMoFCrGbpVmap1kYUG5BFgAOojqo",
            "id": "_design/9815a87f52b7b3d30b3d89ec914cf56cc78ded35",
            "changes": [
              {"rev": "1-d5560cdc2fa6d92f8255eadc430b0ee1"}
            ]
          })
        }),
        true);
  });
  group("error handling", () {
    test("exists operator", () {
      try {
        final exists = ExistsOperator(key: "1", expected: "10");
        exists.evaluate({"1": 10});
      } catch (e) {
        expect(e, isA<AdapterException>());
      }
    });
    test("In Operator", () {
      try {
        final inOperator = InOperator(key: "test", expected: "10");
        inOperator.evaluate({"test": 10});
      } catch (e) {
        expect(e, isA<AdapterException>());
      }
    });
    test("Not In Operator", () {
      try {
        final inOperator = InOperator(key: "test", expected: {10: 10});
        inOperator.evaluate({"test": 10});
      } catch (e) {
        expect(e, isA<AdapterException>());
      }
    });
    test("Size operator", () {
      try {
        final size = SizeOperator(key: "test", expected: "1");
        size.evaluate({
          "test": ["a"]
        });
      } catch (e) {
        expect(e, isA<AdapterException>());
      }
    });

    test("Mod Operator", () {
      try {
        final mod = ModOperator(key: "test", expected: [12.5, 12]);
        mod.evaluate({"test": 100});
      } catch (e) {
        expect(e, isA<AdapterException>());
      }
    });

    test("Regex Operator", () {
      try {
        final mod = ModOperator(key: "test", expected: 12);
        mod.evaluate({"test": "12"});
      } catch (e) {
        expect(e, isA<AdapterException>());
      }
    });
  });

  test("toJson()", () {
    var and = AndOperator();
    var innerAnd = AndOperator(operators: [
      GreaterThanOperator(key: "no", expected: 10),
      LessThanOperator(key: "no", expected: 15)
    ]);
    and.operators
        .addAll([innerAnd, EqualOperator(key: "name", expected: "nasi lemak")]);
    expect(
        and.toJson(),
        equals({
          "\$and": [
            {
              "\$and": [
                {
                  "no": {"\$gt": 10}
                },
                {
                  "no": {"\$lt": 15}
                }
              ]
            },
            {
              "name": {"\$eq": "nasi lemak"}
            }
          ]
        }));
  });
}
