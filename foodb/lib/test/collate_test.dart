import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/collate.dart';

/**
 * https://docs.couchdb.org/en/main/ddocs/views/collation.html#all-docs
 * https://pouchdb.com/faq.html#couchdb_differences
 * 
 * due to different of collation behaviour between view and alldoc in couchdb.
 * and requirement to run foodb in different database adapter
 * we've decided to follow pouchdb design, where string sorting is by ascii
 */
List<dynamic> couchdbCollations = [
  null,
  false,
  true,
  -4,
  1,
  2,
  3.0,
  4,
  'A',
  'B',
  'a',
  'aa',
  'b',
  'ba',
  'bb',
  ["a"],
  ["b"],
  ["b", "c"],
  ["b", "c", "a"],
  ["b", "d"],
  ["b", "d", "e"],
  {"a": 1},
  {"a": 2},
  {"b": 1},
  {"b": 2},
  {"b": 2, "a": 1},
  {"b": 2, "c": 2},
];

void main() {
  test('stripping reserved key', () {
    final str = '\u0001\u0001\u0000\u0001\u0000\u0002\u0000\u0002\u0002';
    expect(revertStripReservedCharacter(stripReservedCharacter(str)), str);
    expect(
        revertStripReservedCharacter(revertStripReservedCharacter(
            stripReservedCharacter(stripReservedCharacter(str)))),
        str);
  });
  test('complex array', () {
    final ori = [
      [
        [null]
      ],
      true,
      {},
      [1],
      ['a'],
    ];
    final encoded = encodeToIndex(ori);
    final decoded = decodeFromIndex(encoded);
    expect(decoded, ori);
  });
  test('complex object', () {
    final ori = {
      'a': ['a'],
      'b': false,
      'c': 123,
      'd': {
        'a': ['z'],
        'd': '123124'
      }
    };
    final encoded = encodeToIndex(ori);
    final decoded = decodeFromIndex(encoded);
    expect(decoded, ori);
  });
  test('follow couchdb specification', () {
    ;
    var keys = couchdbCollations.map((e) => encodeToIndex(e)).toList();
    keys.sort((a, b) => a.compareTo(b));
    var result = keys.map((e) => decodeFromIndex(e)).toList();
    expect(result, couchdbCollations);
  });
}
