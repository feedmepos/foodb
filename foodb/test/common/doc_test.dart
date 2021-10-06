import 'package:test/test.dart';
import 'package:foodb/common.dart';

void main() {
  test('copywith', () {
    Doc<Map<String, dynamic>> doc =
        new Doc(id: 'test', model: {"name": "I am test", "no": 111});
    Doc newDoc = doc.copyWith(model: {"name": "I am test 2", "no": 999});
    print(newDoc.toJson((value) => value));
    expect(newDoc.model["name"], equals("I am test 2"));
  });
}
