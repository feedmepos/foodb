import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

import 'foodb_objectbox_adapter_test.dart';

void main() {
  FoodbDebug.logLevel = LOG_LEVEL.debug;
  replicateBenchmarkTest(
    source: CouchdbTestContext(),
    // source: ObjectBoxTestContext(),
    // target: CouchdbTestContext(),
    target: ObjectBoxTestContext(),
    customSourceDb: 'restaurant_5f3ba1803d4c3d001b29c18a',
    batchSize: 300,
    thousandDoc: 1,
  );
}
