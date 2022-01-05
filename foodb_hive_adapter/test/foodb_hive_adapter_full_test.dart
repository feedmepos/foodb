import 'package:foodb_test/foodb_test.dart';

import 'foodb_hive_adapter_test.dart';

void main() {
  final sqflite = HiveTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(sqflite);
  });
}
