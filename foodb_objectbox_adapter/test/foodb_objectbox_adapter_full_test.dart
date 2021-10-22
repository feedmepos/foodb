import 'package:foodb_test/foodb_test.dart';

import 'foodb_objectbox_adapter_test.dart';

void main() {
  final objectBox = ObjectBoxTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(objectBox);
  });
}
