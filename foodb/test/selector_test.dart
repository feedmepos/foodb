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
    and.operators.addAll([equal1, equal2]);
    expect(and.evaluate(), true);
  });

  test('or, not equal', () {
    final or = OrOperator();
    final equal1 = NotEqualOperator();
    equal1.value = 'a';
    equal1.expected = 'a';
    
    final equal2 = NotEqualOperator();
    equal2.value = 'a';
    equal2.expected = 'b';
    or.operators.addAll([equal1, equal2]);
    expect(or.evaluate(), true);
  });
}
