import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/selector.dart';

void main() {
  test('and, equal', () {
    final and = AndOperator();
    final equal1 = EqualOperator();
    equal1.value = 'a';
    equal1.expected = 'a';

    final equal2 = EqualOperator();
    equal2.value = 1;
    equal2.expected = 1;

    final equal3 = EqualOperator();
    equal3.value = [
      "1",
      {1: "a"}
    ];
    equal3.expected = [
      "1",
      {1: "a"}
    ];

    final equal4 = EqualOperator();
    equal4.value = {
      "a": [1, 2]
    };
    equal4.expected = {
      "a": [1, 2]
    };

    and.operators.addAll([equal1, equal2, equal3, equal4]);
    expect(and.evaluate(), true);
  });
  test('or, not equal', () {
    final or = OrOperator();
    final notEqual1 = NotEqualOperator();
    notEqual1.value = 'a';
    notEqual1.expected = 'a';

    final notEqual2 = NotEqualOperator();
    notEqual2.value = 'a';
    notEqual2.expected = 'b';

    or.operators.addAll([notEqual1, notEqual2]);
    expect(or.evaluate(), true);
  });
  test('and, not equal', () {
    final and = AndOperator();
    final notEqual1 = NotEqualOperator();
    notEqual1.value = {
      12: ["a"]
    };
    notEqual1.expected = {
      12: ["b"]
    };

    final notEqual2 = NotEqualOperator();
    notEqual2.value = [
      {1: 'a'}
    ];
    notEqual2.expected = [
      {1: 'b'}
    ];
    and.operators.addAll([notEqual1, notEqual2]);
    expect(and.evaluate(), true);
  });
  test("and,greater than", () {
    final and = AndOperator();
    final greaterThan1 = GreaterThanOperator();
    greaterThan1.value = 1;
    greaterThan1.expected = 0;

    final greaterThan2 = GreaterThanOperator();
    greaterThan2.value = "nasi lemak";
    greaterThan2.expected = "ayam";
    and.operators.addAll([greaterThan1,greaterThan2]);
    expect(and.evaluate(), true);
  });

  test("and, greater than or equal", () {
    final and = AndOperator();
    final greaterThan1 = GreaterThanOrEqualOperator();
    greaterThan1.value = 100;
    greaterThan1.expected = 100;

    final greaterThan2 = GreaterThanOrEqualOperator();
    greaterThan2.value = "nasi lemak";
    greaterThan2.expected = "ayam";
    and.operators.addAll([greaterThan1, greaterThan2]);
    expect(and.evaluate(), true);
  });

  test("and, less than", () {
    final and = AndOperator();
    final lessThan1 = LessThanOperator();
    lessThan1.value = 0;
    lessThan1.expected = 1;

    final lessThan2 = LessThanOperator();
    lessThan2.value = "ayam";
    lessThan2.expected = "nasi lemak";
    and.operators.addAll([lessThan1, lessThan2]);
    expect(and.evaluate(), true);
  });
  test("and, less than or equal", () {
    final and = AndOperator();
    final lessThan1 = LessThanOrEqualOperator();
    lessThan1.value = 0;
    lessThan1.expected = 0;

    final lessThan2 = LessThanOrEqualOperator();
    lessThan2.value = "ayam";
    lessThan2.expected = "nasi lemak";
    and.operators.addAll([lessThan1, lessThan2]);
    expect(and.evaluate(), true);
  });
  test("and, exists", () {
    final and = AndOperator();
    final exists1 = ExistsOperator();
    exists1.value = null;
    exists1.expected = false;

    final exists2 = ExistsOperator();
    exists2.value = "pedas";
    exists2.expected = true;

    and.operators.addAll([exists1, exists2]);
    expect(and.evaluate(), true);
  });
  test("and, type", () {
    final and = AndOperator();
    final type1 = TypeOperator();
    type1.value = "string";
    type1.expected = "string";

    final type2 = TypeOperator();
    type2.value = {};
    type2.expected = "object";

    final type3 = TypeOperator();
    type3.value = [];
    type3.expected = "array";

    and.operators.addAll([type1, type2, type3]);
    expect(and.evaluate(), true);
  });
  test("and, in, not in", () {
    final and = AndOperator();
    final type1 = InOperator();
    type1.value = {1: 2};
    type1.expected = [
      3,
      {1: 2},
      2
    ];

    final type2 = InOperator();
    type2.value = "a";
    type2.expected = ["c", "b", "a"];

    final type3 = NotInOperator();
    type3.value = [1,2];
    type3.expected = [[1], 2, 3];

    final type4 = NotInOperator();
    type4.value = 1;
    type4.expected = ["a", "b", "c"];

    and.operators.addAll([type1, type2, type3, type4]);
    expect(and.evaluate(), true);
  });

  test("and, size", () {
    final and = AndOperator();
    final size = SizeOperator();
    size.value = [1, 2, 3];
    size.expected = 3;

    and.operators.addAll([size]);
    expect(and.evaluate(), true);
  });

  test("and, mod", () {
    final and = AndOperator();
    final mod1 = ModOperator();
    mod1.value = 100;
    mod1.expected = [10, 0];

    final mod2 = ModOperator();
    mod2.value = 10;
    mod2.expected = [3, 1];

    and.operators.addAll([mod1, mod2]);
    expect(and.evaluate(), true);
  });

  test("and, regex", () {
    final and = AndOperator();
    final regex1 = RegexOperator();
    regex1.value = "user_123_burger";
    regex1.expected = "^user";
    print(jsonEncode({
      "seq":
          "2-g1AAAACreJzLYWBgYMxgTmGwT84vTc5ISXKA0row2lAPTUQvJbVMr7gsWS85p7S4JLVILyc_OTEnB2gQUyJDHgvDfyDIymBOZMoFCrGbpVmap1kYUG5BFgAOojqo",
      "id": "_design/9815a87f52b7b3d30b3d89ec914cf56cc78ded35",
      "changes": [
        {"rev": "1-d5560cdc2fa6d92f8255eadc430b0ee1"}
      ]
    }));
    final regex2 = RegexOperator();
    regex2.value = jsonEncode({
      "seq":
          "2-g1AAAACreJzLYWBgYMxgTmGwT84vTc5ISXKA0row2lAPTUQvJbVMr7gsWS85p7S4JLVILyc_OTEnB2gQUyJDHgvDfyDIymBOZMoFCrGbpVmap1kYUG5BFgAOojqo",
      "id": "_design/9815a87f52b7b3d30b3d89ec914cf56cc78ded35",
      "changes": [
        {"rev": "1-d5560cdc2fa6d92f8255eadc430b0ee1"}
      ]
    });
    regex2.expected = "^{\".*},?\n?\$";

    and.operators.addAll([regex1, regex2]);
    expect(and.evaluate(), true);
  });
}
