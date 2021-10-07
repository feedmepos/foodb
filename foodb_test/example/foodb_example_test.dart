import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';

void main() {
  group('couchdb', () {
    final ctx = CouchdbTestContext();
    fullTestSuite.asMap().keys.forEach((key) {
      final test = fullTestSuite[key];
      test(ctx);
    });
  });

  group('in memory', () {
    final ctx = InMemoryTestContext();
    fullTestSuite.asMap().keys.forEach((key) {
      final test = fullTestSuite[key];
      test(ctx);
    });
  });
}
