import 'package:foodb_test/foodb_test.dart';

void main() {
  final ctx = CouchdbTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(ctx);
  });
}
