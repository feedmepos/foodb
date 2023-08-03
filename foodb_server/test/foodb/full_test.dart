import 'package:foodb_test/foodb_test.dart';

import 'context.dart';

void main() {
  final httpServer = HttpServerCouchdbTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(httpServer);
  });
}
