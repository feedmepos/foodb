import 'package:flutter_test/flutter_test.dart';
import 'package:quiver/collection.dart';

void main() {
  test('', () {
    var tree = AvlTreeSet<String>();
    tree.add('a');
    tree.add('c');
    var iterator = tree.iterator;
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'a');
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'c');
    expect(iterator.moveNext(), false);

    iterator = tree.reverseIterator;
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'c');
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'a');
    expect(iterator.moveNext(), false);

    iterator = tree.fromIterator('a');
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'a');

    iterator = tree.fromIterator('a', reversed: true);
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'a');

    iterator = tree.fromIterator('a', inclusive: false);
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'c');

    iterator = tree.fromIterator('a', reversed: true, inclusive: false);
    expect(iterator.moveNext(), false);

    iterator = tree.fromIterator('b');
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'c');

    iterator = tree.fromIterator('b', inclusive: false);
    expect(iterator.moveNext(), true);
    expect(iterator.current, 'c');

    iterator = tree.fromIterator('d');
    expect(iterator.moveNext(), false);
  });
}
