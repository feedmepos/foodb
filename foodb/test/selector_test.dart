import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/selector.dart';

void main() {
  test('combination equal', () {
    final and = AndOperator();
    final equal1 = EqualOperator();
    equal1.value = 'a';
    equal1.expected = 'a';
    final equal2 = EqualOperator();
    equal2.value = 'a';
    equal2.expected = 'b';
    and.operators.addAll([equal1, equal2]);
    expect(and.evaluate(), true);
  });
}
