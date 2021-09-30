import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/design_doc.dart';

// class PartialFilterSelector {
//   Map<String, dynamic> value = {};

//   PartialFilterSelector();

//   Map<String, dynamic> rebuildSelector(Map<String, dynamic> json) {
//     List<dynamic> subList = [];
//     json.entries.forEach((element) {
//       subList.add(DFS(Map.fromEntries([element])));
//     });
//     if (subList.length > 1)
//       this.value = {CombinationOperator.and: subList};
//     else {
//       this.value = subList.first;
//     }

//     return this.value;
//   }

//   Map<String, dynamic> DFS(Map<String, dynamic> json) {
//     for (MapEntry<String, dynamic> entry in json.entries) {
//       if (entry.key == CombinationOperator.and) {
//         List<dynamic> subList = [];
//         entry.value.forEach((e) {
//           subList.add(DFS(e));
//         });
//         if (this.value.length > 1) {
//           this.value = {
//             CombinationOperator.and: [
//               value,
//               {CombinationOperator.and: subList}
//             ]
//           };
//         } else {
//           this.value = {CombinationOperator.and: subList};
//         }

//         return this.value;
//       } else {
//         if (entry.value.length > 1) {
//           List<dynamic> subList = [];
//           entry.value.forEach((operator, arg) {
//             subList.add({
//               entry.key: {operator: arg}
//             });
//           });

//           return <String, dynamic>{CombinationOperator.and: subList};
//         }
//         return {entry.key: entry.value};
//       }
//     }
//     return this.value;
//   }
// }

void main() {
  test('test DFS with multiple operator within one entry', () {
    PartialFilterSelector partialFilterSelector = new PartialFilterSelector();
    partialFilterSelector.generateSelector({
      "no": {"\$gt": 100, "\$lt": 300},
      "name": {"\$gt": 100, "\$lt": 300}
    });

    print(jsonEncode(partialFilterSelector.value));
    expect(partialFilterSelector.value.length, greaterThan(0));
    expect(
        partialFilterSelector.value,
        equals({
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
        }));
    expect(partialFilterSelector.keys.length, equals(2));
  });
  test("test DFS with multiple and", () {
    PartialFilterSelector partialFilterSelector = new PartialFilterSelector();
    partialFilterSelector.generateSelector({
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
              "name": {"\$gt": 300}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        }
      ]
    });

    print(jsonEncode(partialFilterSelector.value));
    expect(partialFilterSelector.value.length, greaterThan(0));
    expect(partialFilterSelector.value, {
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
              "name": {"\$gt": 300}
            },
            {
              "name": {"\$lt": 300}
            }
          ]
        }
      ]
    });
    expect(partialFilterSelector.keys.length, equals(2));
  });

  test('test DFS with complex structure', () {
    PartialFilterSelector partialFilterSelector = new PartialFilterSelector();
    Map<String, dynamic> value = partialFilterSelector.generateSelector({
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

    print(jsonEncode(value));
    expect(value.length, greaterThan(0));
    expect(
        value,
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

    expect(partialFilterSelector.keys.length, equals(2));
  });
}
