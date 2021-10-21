import 'package:foodb_test/foodb_test.dart';

void main() {
  final couchdb = CouchdbTestContext();
  fullTestSuite.forEach((testCase) {
    testCase(couchdb);
  });
}
