import 'package:foodb_test/foodb_test.dart';

void main() {
  // final db = CouchdbTestContext();
  final db = InMemoryTestContext();
  // final db = HttpServerCouchdbTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(db);
  });
}
