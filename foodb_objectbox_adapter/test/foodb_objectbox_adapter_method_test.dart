import 'package:foodb_test/foodb_test.dart';

import 'foodb_objectbox_adapter_test.dart';

void main() {
  final objectBox = ObjectBoxTestContext();
  final couchdb = CouchdbTestContext();
  // replicateBenchmarkTest(
  //     source: couchdb, target: objectBox, batchSize: 300, thousandDoc: 5);
  // group('couchdb > objectBox', () {
  //   replicateTest().forEach((t) {
  //     t(couchdb, objectBox);
  //   });
  // });
  // group('objectBox > couchbdb', () {
  //   replicateTest().forEach((t) {
  //     t(objectBox, couchdb);
  //   });
  // });

  // findTest().forEach((fn) {
  //   fn(objectBox);
  // });

  // findBenchmarkTest(3000, objectBox);

  // allDocTest().forEach((fn) {
  //   fn(objectBox);
  // });
  getTest().forEach((fn) {
    fn(objectBox);
  });
  // bulkDocTest().forEach((fn) {
  //   fn(objectBox);
  // });
  // changeStreamTest().forEach((fn) {
  //   fn(objectBox);
  // });
  // deleteTest().forEach((fn) {
  //   fn(objectBox);
  // });
  // putTest().forEach((fn) {
  //   fn(objectBox);
  // });
  // utilTest().forEach((fn) {
  //   fn(objectBox);
  // });
}
