import 'package:foodb_test/foodb_test.dart';

import 'foodb_hive_adapter_test.dart';

void main() {
  final hive = HiveTestContext();
  final couchdb = CouchdbTestContext();
  replicateBenchmarkTest(
      source: couchdb, target: hive, batchSize: 300, thousandDoc: 5);
  // group('couchdb > hive', () {
  //   replicateTest().forEach((t) {
  //     t(couchdb, hive);
  //   });
  // });
  // group('hive > couchbdb', () {
  //   replicateTest().forEach((t) {
  //     t(hive, couchdb);
  //   });
  // });

  // findTest().skip(7).take(1).forEach((fn) {
  //   fn(hive);
  // });

  // findBenchmarkTest(3000, hive);

  // allDocTest().forEach((fn) {
  //   fn(hive);
  // });
  // getTest().forEach((fn) {
  //   fn(hive);
  // });
  // bulkDocTest().forEach((fn) {
  //   fn(hive);
  // });
  // changeStreamTest().forEach((fn) {
  //   fn(hive);
  // });
  // deleteTest().forEach((fn) {
  //   fn(hive);
  // });
  // putTest().forEach((fn) {
  //   fn(hive);
  // });
  // utilTest().forEach((fn) {
  //   fn(hive);
  // });
}
