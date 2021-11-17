import 'package:foodb_test/foodb_test.dart';

import 'foodb_objectbox_adapter_test.dart';

void main() {
  final objectBox = ObjectBoxTestContext();
  findBenchmarkTest(10000, objectBox);
}
