import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';

void main() {
  group('couchdb', () {
    final ctx = CouchdbTestContext();
    foodbFullTestSuite.asMap().keys.forEach((key) {
      final test = foodbFullTestSuite[key];
      test(ctx);
    });
  });

  group('in memory', () {
    final ctx = InMemoryTestContext();
    foodbFullTestSuite.asMap().keys.forEach((key) {
      final test = foodbFullTestSuite[key];
      test(ctx);
    });
  });
}
