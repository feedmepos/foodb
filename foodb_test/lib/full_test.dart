import 'package:foodb_test/foodb_test.dart';

void main() {
  // final db = CouchdbTestContext();
  final db = InMemoryTestContext();
  // final db = HttpServerCouchdbTestContext();
  // final db = WebSocketServerCouchdbTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(db);
  });
}
