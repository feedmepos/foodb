// import 'dart:io';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:foodb/adapter/adapter.dart';
// import 'package:foodb/adapter/couchdb_adapter.dart';
// import 'package:foodb/adapter/key_value_adapter.dart';
// import 'package:foodb/adapter/methods/all_docs.dart';
// import 'package:foodb/adapter/methods/changes.dart';
// import 'package:foodb/common/doc.dart';
// import 'package:foodb/common/rev.dart';
// import 'package:foodb/replicator.dart';
// import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';

// void main() async {
//   // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
//   TestWidgetsFlutterBinding.ensureInitialized();
//   HttpOverrides.global = null;
//   await dotenv.load(fileName: ".env");

//   String envDbName = dotenv.env['COUCHDB_DB_NAME'] as String;
//   String benchDbName = dotenv.env['COUCHDB_DB_BENCHMARKS'] as String;
//   String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;
//   String localUri = dotenv.env['COUCHDB_LOCAL_URI'] as String;
//   String dbName = dotenv.env['OBJECTBOX_DB_NAME'] as String;

//   getCouchDbAdapter({String? dbName}) {
//     return new CouchdbAdapter(
//         dbName: dbName ?? envDbName, baseUri: Uri.parse(baseUri));
//   }

//   getLocalCouchDbAdapter({String? dbName}) {
//     return new CouchdbAdapter(
//         dbName: dbName ?? benchDbName, baseUri: Uri.parse(localUri));
//   }

//   getObjectBox() {
//     ObjectBox objectBox = new ObjectBox();
//     return objectBox;
//   }

//   test('check replicator with 2 couchdb', () async {
//     await getLocalCouchDbAdapter(dbName: "adish").destroy();
//     await getLocalCouchDbAdapter(dbName: "adish").init();

//     var fn = expectAsync1((result) {
//       print("in fn");
//       expect(result, "Completed");
//     });

//     Replicator(
//             source: getLocalCouchDbAdapter(dbName: "restaurant"),
//             target: getLocalCouchDbAdapter(dbName: "adish"))
//         .replicate(
//             live: false,
//             timeout: Duration(milliseconds: 500),
//             limit: 5000,
//             onData: (data) {
//               //print(data);
//             },
//             onError: (error, retry) {
//               print(error);
//             },
//             onComplete: (result) {
//               print(result);
//               fn(result);
//             });
//   }, timeout: Timeout.none);
//   test("generate 40k DB", () async {
//     final couchdb = getLocalCouchDbAdapter(dbName: "fortyk");
//     // await couchdb.destroy();
//     // await couchdb.initDb();

//     List<Doc<Map<String, dynamic>>> docs = [];
//     for (int x = 30000; x < 40000; x++) {
//       docs.add(Doc(id: "$x", model: {"name": "$x nasi lemak", "no": x}));
//       print(x);
//     }
//     await couchdb.bulkDocs(body: docs, newEdits: true);
//   }, timeout: Timeout.none);
//   test("generate 5k DB", () async {
//     final couchdb = getCouchDbAdapter(dbName: "fthousand");
//     await couchdb.destroy();
//     await couchdb.initDb();

//     List<Doc<Map<String, dynamic>>> docs = [];
//     for (int x = 0; x < 5000; x++) {
//       docs.add(Doc(id: "$x", model: {"name": "$x nasi lemak", "no": x}));
//       print(x);
//     }
//     await couchdb.bulkDocs(body: docs, newEdits: true);
//   }, timeout: Timeout.none);

//   test('check replicator with 2 couchdb', () async {
//     await getLocalCouchDbAdapter(dbName: "tenk").destroy();
//     await getLocalCouchDbAdapter(dbName: "tenk").initDb();

//     var fn = expectAsync1((result) {
//       print("in fn");
//       expect(result, "Completed");
//     });

//     Replicator(
//             source: getCouchDbAdapter(dbName: 'tenk'),
//             target: getLocalCouchDbAdapter(dbName: "tenk"))
//         .replicate(
//             live: false,
//             limit: 5000,
//             timeout: Duration(milliseconds: 500),
//             onData: (data) {
//               print(data);
//               // if (data == "One Cycle Completed") ++count;
//               // if (count == 2) {
//               //   fn(data);
//               // }
//             },
//             onError: (error, retry) {
//               print(error);
//             },
//             onComplete: (result) {
//               print(result);
//               fn(result);
//             });
//   }, timeout: Timeout.none);
//   test('check synchronization with 2 couchdb', () async {
//     await getCouchDbAdapter(dbName: "a-test").destroy();
//     await getCouchDbAdapter(dbName: "a-test").initDb();

//     PutResponse putResponse = await getCouchDbAdapter(dbName: "adish").put(
//       doc: Doc(
//           id: "feedme",
//           rev: Rev.fromString("1-asdfg"),
//           model: {"name": "feedmefood", "no": 300}),
//       newEdits: false,
//     );
//     expect(putResponse.ok, isTrue);

//     PutResponse putResponse2 = await getCouchDbAdapter(dbName: "adish").put(
//       doc: Doc(
//           id: "feedme",
//           model: {"name": "feedmecola", "no": 200},
//           rev: Rev.fromString("2-asdfg"),
//           revisions: Revisions(start: 2, ids: ["asdfg", "asdfg"])),
//       newEdits: false,
//     );
//     expect(putResponse2.ok, isTrue);

//     PutResponse putResponse3 = await getCouchDbAdapter(dbName: "adish").put(
//       doc: Doc(
//           id: "feedme",
//           model: {"name": "feedmeburger", "no": 900},
//           rev: Rev.fromString("2-bbdfg"),
//           revisions: Revisions(ids: ["bbdfg", "asdfg"], start: 2)),
//       newEdits: false,
//     );
//     expect(putResponse3.ok, isTrue);

//     await getCouchDbAdapter(dbName: "a-test").destroy();
//     await getCouchDbAdapter(dbName: "a-test").initDb();

//     //case 1
//     //case 2
//     await getCouchDbAdapter(dbName: "a-test").put(
//       doc: Doc(
//           id: "feedme",
//           rev: Rev.fromString("1-asdfg"),
//           model: {"name": "feedmefood", "no": 300}),
//       newEdits: false,
//     );

//     // case 3
//     await getCouchDbAdapter(dbName: "a-test").put(
//       doc: Doc(
//           id: "feedme",
//           model: {"name": "starvation", "no": 999},
//           rev: Rev.fromString("2-zzzzz"),
//           revisions: Revisions(ids: ["zzzzz", "asdfg"], start: 2)),
//       newEdits: false,
//     );

//     // var fn3 = expectAsync1((result) {
//     //   print(result);
//     //   expect(result, isInstanceOf<Exception>());
//     // });

//     // var fn2 = expectAsync1((result) {
//     //   // print("in fn2");
//     //   print(result == "One Cycle Completed");
//     //   replicator.cancelStream();

//     //   expect(result, equals("One Cycle Completed"));
//     // });

//     var fn4 = expectAsync1((result) {
//       expect(result, "Completed");
//     });

//     var fn = expectAsync1((result) {
//       // print("in fn");
//       print(result == "Completed");
//       expect(result, equals("Completed"));

//       replicator2.replicate(
//           live: false,
//           timeout: Duration(milliseconds: 500),
//           onData: (data) {
//             print(data);
//           },
//           onError: (error, retry) {
//             print(error);
//             retry();
//           },
//           onComplete: (result) {
//             print(result);
//             fn4(result);
//           });
//     });

//     int count = 0;

//     replicator.replicate(
//         live: false,
//         limit: 5,
//         timeout: Duration(milliseconds: 500),
//         onData: (data) {
//           print(data);
//           if (data == "One Cycle Completed") ++count;
//           // if (count == 2) {
//           //   // fn2(data);
//           // }
//         },
//         onError: (error, retry) {
//           print(error);
//           print("error ${error.runtimeType}");
//           //if (count == 2)
//           //fn3(error);

//           retry();
//         },
//         onComplete: (result) {
//           print("DONE HERE $result");
//           fn(result);
//         });

//     // Future.delayed(Duration(seconds: 10)).then((value) => {
//     //       getCouchDbAdapter()
//     //           .put(doc: Doc(id: "fn2", model: {"name": "fueffd", "no": 999}))
//     //     });
//   });
//   test("check replicator from objectBox to couchdb", () async {
//     final couchdb = getCouchDbAdapter(dbName: "a-test");
//     await couchdb.destroy();
//     await couchdb.initDb();

//     final object = await getObjectBox();
//     await object.deleteDatabase();

//     final objectBox = new KeyValueAdapter(dbName: dbName, db: object);
//     await objectBox.put(doc: Doc(id: "1", model: {"name": "abc", "no": 123}));
//     await objectBox.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-b"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);
//     await objectBox.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
//     await objectBox.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

//     Replicator replicator = new Replicator(source: objectBox, target: couchdb);

//     var fn = expectAsync1((result) async {
//       print("in fn");
//       expect(result, "Completed");
//       GetAllDocsResponse response =
//           await couchdb.allDocs(GetAllDocsRequest(), (json) => json);
//       expect(response.rows.length, 3);

//       // var fn = expectAsync1((result) {
//       //   print("in continuous");
//       //   replicator.cancelAll();

//       //   expect(result, equals("One Cycle Completed"));
//     });

//     int count = 0;
//     replicator.replicate(
//         live: false,
//         limit: 2,
//         timeout: Duration(milliseconds: 500),
//         onError: (e, retry) {
//           print(e);
//           //retry();
//         },
//         onData: (data) {
//           print(data);
//           // if (data == "One Cycle Completed") ++count;
//           // if (count == 2) {
//           //   fn(data);
//           // }
//         },
//         onComplete: (result) {
//           print(result);
//           fn(result);
//         });

//     // await Future.delayed(Duration(seconds: 10)).then((value) => {
//     //       objectBox.put(doc: Doc(id: "test1", model: {"name": "a", "no": 999}))
//     //     });
//     // await Future.delayed(Duration(seconds: 2)).then((value) => {
//     //       objectBox.put(doc: Doc(id: "test2", model: {"name": "b", "no": 999}))
//     //     });
//   });
//   test("check replicator from couchdb to objectBox", () async {
//     final couchdb = getCouchDbAdapter();
//     final object = getObjectBox();
//     await object.deleteDatabase();

//     final objectBox = await KeyValueAdapter(db: object, dbName: dbName);
//     await couchdb.destroy();
//     await couchdb.initDb();
//     await couchdb.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-b"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);

//     await couchdb.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-a"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);
//     await couchdb.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
//     await couchdb.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

//     Replicator replicator = new Replicator(source: couchdb, target: objectBox);

//     var fn = expectAsync1((result) async {
//       print("in fn");
//       expect(result, "Completed");

//       GetAllDocsResponse allDocsResponse =
//           await objectBox.allDocs(GetAllDocsRequest(), (json) => json);
//       print(allDocsResponse.toJson((value) => value));
//       expect(allDocsResponse.rows.length, equals(3));
//       expect(result, "Completed");
//     });

//     // var fn = expectAsync1((result) {
//     //   print("in continuous");
//     //   replicator.cancelAll();

//     //   expect(result, equals("One Cycle Completed"));
//     // });

//     int count = 0;
//     replicator.replicate(
//         live: false,
//         timeout: Duration(milliseconds: 500),
//         onError: (e, retry) {
//           print(e);
//           //retry();
//         },
//         onData: (data) {
//           print(data);
//           // if (data == "One Cycle Completed") ++count;
//           // if (count == 2) {
//           //   fn(data);
//           // }
//         },
//         onComplete: (result) {
//           print(result);
//           fn(result);
//         });
//     await Future.delayed(Duration(seconds: 5)).then((value) => {
//           couchdb.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
//         });
//     await Future.delayed(Duration(seconds: 2)).then((value) => {
//           couchdb.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
//         });

//     // print((await objectBox.allDocs(GetAllDocsRequest(), (json) => json))
//     //     .toJson((value) => value));
//   });
//   test("check replicator from couchdb to objectBox with changeStream",
//       () async {
//     final object = getObjectBox();
//     await object.deleteDatabase();

//     final objectBox = KeyValueAdapter(dbName: dbName, db: object);
//     final couchdb = getCouchDbAdapter(dbName: "a-test");

//     await couchdb.destroy();
//     await couchdb.initDb();
//     await couchdb.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-b"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);

//     await couchdb.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-a"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);
//     await couchdb.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
//     await couchdb.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

//     Replicator replicator = new Replicator(source: couchdb, target: objectBox);

//     var fn = expectAsync1((result) {
//       print("in fn");
//       expect(result, "Completed");
//     });

//     // var fn = expectAsync1((result) async {
//     //   await replicator.cancelAll();
//     //   expect(result, equals("One Cycle Completed"));
//     // });

//     int count = 0;
//     replicator.replicate(
//         live: false,
//         timeout: Duration(milliseconds: 500),
//         onError: (e, retry) {
//           print(e);
//           //retry();
//         },
//         onData: (data) {
//           print(data);
//           // if (data == "One Cycle Completed") ++count;
//           // if (count == 2) {
//           //   fn(data);
//           // }
//         },
//         onComplete: (result) {
//           print(result);
//           fn(result);
//         });
//     int count2 = 0;
//     var fc1 = expectAsync1((ChangeResult changeResult) {
//       print("Verify: ${changeResult.toJson()}");
//       expect(changeResult.id, equals("1"));
//     });

//     var fc2 = expectAsync1((ChangeResult changeResult) {
//       print("Verify: ${changeResult.toJson()}");
//       expect(changeResult.id, equals("2"));
//     });

//     var fc3 = expectAsync1((ChangeResult changeResult) {
//       print("Verify: ${changeResult.toJson()}");
//       expect(changeResult.id, equals("3"));
//     });

//     // var fc5 = expectAsync1((ChangeResult changeResult) {
//     //   print("Verify: ${changeResult.toJson()}");
//     //   expect(changeResult.id, equals("4"));
//     // });

//     Future.delayed(Duration(seconds: 5)).then((value) => {
//           couchdb.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
//         });
//     Future.delayed(Duration(seconds: 10)).then((value) => {
//           couchdb.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
//         });

//     ChangesStream changesStream = await objectBox
//         .changesStream(ChangeRequest(feed: ChangeFeed.continuous));
//     changesStream.listen(
//         onResult: expectAsync1((result) {
//       count2++;
//       print("RESULT ${result.toJson()}");
//       if (count2 == 1)
//         fc1(result);
//       else if (count2 == 2)
//         fc2(result);
//       else if (count2 == 3) fc3(result);
//       // else if (count2 == 4) fc4(result);
//       // else if (count2 == 5) fc5(result);
//     }, count: 3));
//   });
//   test("check replicator from objectBox to couchDb with changeStream",
//       () async {
//     final couchdb = getCouchDbAdapter();
//     await couchdb.destroy();
//     await couchdb.initDb();

//     final object = await getObjectBox();
//     final objectBox = new KeyValueAdapter(dbName: dbName, db: object);

//     await objectBox.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-b"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);

//     await objectBox.put(
//         doc: Doc(
//             id: "1",
//             rev: Rev.fromString("1-a"),
//             model: {"name": "abc", "no": 123}),
//         newEdits: false);
//     await objectBox.put(doc: Doc(id: "2", model: {"name": "cde", "no": 124}));
//     await objectBox.put(doc: Doc(id: "3", model: {"name": "cde", "no": 125}));

//     Replicator replicator = new Replicator(source: objectBox, target: couchdb);

//     var fn = expectAsync1((result) async {
//       print("in fn");
//     });

//     // var fn = expectAsync1((result) async {
//     //   await replicator.cancelAll();
//     //   expect(result, equals("One Cycle Completed"));
//     // });

//     int count = 0;
//     replicator.replicate(
//         live: false,
//         timeout: Duration(milliseconds: 500),
//         onError: (e, retry) {
//           print(e);
//           //retry();
//         },
//         onData: (data) {
//           //print(data);
//           // if (data == "One Cycle Completed") ++count;
//           // if (count == 2) {
//           //   fn(data);
//           // }
//         },
//         onComplete: (result) {
//           print(result);
//           fn(result);
//         });
//     int count2 = 0;

//     var fc1 = expectAsync1((ChangeResult changeResult) {
//       print("Verify: ${changeResult.toJson()}");
//       expect(changeResult.id, equals("1"));
//     });

//     var fc2 = expectAsync1((ChangeResult changeResult) {
//       print("Verify: ${changeResult.toJson()}");
//       expect(changeResult.id, equals("2"));
//     });

//     var fc3 = expectAsync1((ChangeResult changeResult) {
//       print("Verify: ${changeResult.toJson()}");
//       expect(changeResult.id, equals("3"));
//     });

//     // var fc4 = expectAsync1((ChangeResult changeResult) {
//     //   print("Verify: ${changeResult.toJson()}");
//     //   expect(changeResult.id, equals("4"));
//     // });

//     Future.delayed(Duration(seconds: 5)).then((value) => {
//           objectBox.put(doc: Doc(id: "4", model: {"name": "a", "no": 999}))
//         });
//     Future.delayed(Duration(seconds: 10)).then((value) => {
//           objectBox.put(doc: Doc(id: "5", model: {"name": "b", "no": 999}))
//         });

//     ChangesStream changesStream =
//         await couchdb.changesStream(ChangeRequest(feed: ChangeFeed.continuous));
//     changesStream.listen(
//         onResult: expectAsync1((result) {
//       count2++;
//       print("RESULT ${result.toJson()}");
//       if (count2 == 1)
//         fc1(result);
//       else if (count2 == 2)
//         fc2(result);
//       else if (count2 == 3) fc3(result);
//       // else if (count2 == 4) fc4(result);
//     }, count: 3));
//   });
//   test("couchdb check missed id", () async {
//     final localCouch = getLocalCouchDbAdapter(dbName: 'restaurant');
//     GetAllDocsResponse response = await localCouch.allDocs(
//         GetAllDocsRequest(includeDocs: true), (json) => json);
//     List<String> couchIds = response.rows.map((e) => e.doc!.id).toList();
    
//     final box = new ObjectBox();
//     ReadResult response2 = await box.read(DocDataType());
//     List<String> ids = response2.docs.keys.toList();

//     print("check ids");
//     List<String> missed = [];
//     ids.forEach(((e) {
//       if (!couchIds.contains(e)) {
//         missed.add(e);
//         print(e);
//       }
//     }));

//     print("response.totalRows: ${response.totalRows}");
//     print("response2.totalRows: ${response2.totalRows}");
//     print("response.rows.length: ${response.rows.length}");
//     print("response2.rows.length: ${response2.docs.length}");

//     expect(missed.length, 0);
//   }, timeout: Timeout.none);
//   test("Benchmark: Replication From Couchdb to ObjectBox with 40K docs ",
//       () async {
//     final couchdb = getLocalCouchDbAdapter(dbName: 'fortyk');

//     final object = await getObjectBox();
//     await object.deleteDatabase();

//     final objectBox = new KeyValueAdapter(dbName: 'fortyk', db: object);

//     var fn = expectAsync1((result) async {
//       print("in fn");
//       int size = await object.tableSize(DocDataType());
//       expect(size, 40000);
//     });

//     // var fn2 = expectAsync0(() async {
//     //   objectBox
//     //       .allDocs(GetAllDocsRequest(), (json) => json)
//     //       .then((value) => expect(value.rows.length, equals(40000)));
//     // });

//     Stopwatch stopwatch = new Stopwatch();
//     stopwatch.start();
//     Replicator(source: couchdb, target: objectBox).replicate(
//         live: false,
//         limit: 5000,
//         timeout: Duration(milliseconds: 500),
//         onError: (e, retry) {
//           print(e.toString());
//         },
//         onData: (data) {
//           //print(data);
//         },
//         onComplete: (result) async {
//           stopwatch.stop();
//           print("Timetaken: ${stopwatch.elapsedMilliseconds}");
//           fn(result);
//         });
//   }, timeout: Timeout.none);

//   test("check total docs replicated from couchdb", () async {
//     final objectBox = KeyValueAdapter(dbName: "fortyk", db: getObjectBox());
//     final GetAllDocsResponse response =
//         await objectBox.allDocs(GetAllDocsRequest(), (json) => json);
//     print(response.toJson((value) => value));
//     expect(response.totalRows, equals(40000));
//   }, timeout: Timeout.none);

//   test("test objectbox length", () async {
//     final objectBox = KeyValueAdapter(dbName: dbName, db: getObjectBox());
//     GetAllDocsResponse response =
//         await objectBox.allDocs(GetAllDocsRequest(), (json) => json);
//     expect(response.rows.length, 44428);
//     expect(response.totalRows, 44428);
//   }, timeout: Timeout.none);

//     final objectBox =
//         new KeyValueAdapter(dbName: 'restaurant', db: getObjectBox());

//     var fn = expectAsync1((result) {
//       print("in fn");
//       expect(result, "Completed");
//     });

//     Replicator(
//             source: getCouchDbAdapter(dbName: "benchtest"), target: objectBox)
//         .replicate(
//             live: false,
//             limit: 3000,
//             onData: (data) {
//               //print(data);
//             },
//             onError: (error, retry) {},
//             onComplete: (response) {
//               print(response);
//               fn(response);
//             });
//   }, timeout: Timeout.none);
// }
