import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:path/path.dart';

Future<ObjectBoxAdapter> getAdapter(String dbName,
    {bool persist = false}) async {
  var directory = join(Directory.current.path, 'temp/$dbName');
  final dir = Directory(directory);
  late Store store;
  if (!persist) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    addTearDown(() {
      store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }
  store = await openStore(directory: directory);
  final adapter = ObjectBoxAdapter(store);
  await adapter.initDb();
  return adapter;
}

class ObjectBoxTestContext extends FoodbTestContext {
  @override
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix = 'test-'}) async {
    var name = '$prefix$dbName';
    var db = await getAdapter(name);
    return Foodb.keyvalue(dbName: '$name', keyValueDb: db);
  }
}

void main() {
  final objectBox = ObjectBoxTestContext();
  final couchdb = CouchdbTestContext();
  // replicateBenchmarkTest(1000, 30, objectBox);
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

  // findBenchmarkTest(10000, objectBox);

  allDocTest().skip(8).take(1).forEach((fn) {
    fn(objectBox);
  });
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
