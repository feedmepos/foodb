import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/foodb_test.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:path/path.dart';

class ObjectBoxTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName) async {
    var directory = join(Directory.current.path, 'temp/$dbName');
    final dir = Directory(directory);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    var db = ObjectBoxAdapter(await openStore(directory: directory));
    await db.destroy();
    return Foodb.keyvalue(dbName: dbName, keyValueDb: db);
  }
}

void main() {
  final objectBox = ObjectBoxTestContext();
  final couchdb = CouchdbTestContext();
  replicateBenchmarkTest(1000, 3, objectBox);
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
  // allDocTest().forEach((fn) {
  //   fn(objectBox);
  // });
  // getTest().forEach((fn) {
  //   fn(objectBox);
  // });
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
