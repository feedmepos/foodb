import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodb/common/rev.dart';
import 'package:uuid/uuid.dart';

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String envDbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  getCouchDbAdapter({String? dbName}) {
    return new CouchdbAdapter(
        dbName: dbName ?? envDbName, baseUri: Uri.parse(baseUri));
  }

  setUp(() async {
    await getCouchDbAdapter().destroy();
    await getCouchDbAdapter().init();
  });

  group('bulkdocs()', () {
    test('bulkdocs() with newEdits= false', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      List<Doc<Map<String, dynamic>>> newDocs = [];
      newDocs.add(Doc(
          id: 'test2',
          rev: Rev.fromString('1-zu21xehvdaine5smjxy9htiegd4rptkm5'),
          model: {
            'name': 'test test',
            'no': 1111,
          },
          revisions: Revisions(start: 1, ids: [
            'zu21xehvdaine5smjxy9htiegd4rptkm5',
            'zu21xehvdaine5smjxy9htiegd4rptkm5'
          ])));
      newDocs.add(Doc(
          id: 'test7',
          rev: Rev.fromString('0-sasddsdsdfdfdsfdffdd'),
          model: {
            'name': 'test test asdfgh',
            'no': 2212,
          },
          revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])));
      newDocs.add(Doc(
          id: 'test5',
          rev: Rev.fromString('0-sasddsdsdfdfdsfdffdd'),
          model: {
            'name': 'test test 5',
            'no': 222,
          },
          revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])));
      BulkDocResponse bulkDocResponse = await couchDb.bulkDocs(body: newDocs);
      expect(bulkDocResponse.putResponses, []);
    });

    test('bulkdocs() with newEdits =true', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      var bulkdocResponse = await couchDb.bulkDocs(body: [
        new Doc<Map<String, dynamic>>(
            id: "test 1", model: {"name": "beefy", "no": 999}),
        new Doc<Map<String, dynamic>>(
            id: "test 2", model: {"name": "soda", "no": 999}),
      ], newEdits: true);

      expect(bulkdocResponse.putResponses.length, 2);
    });
  });

  test('allDocs()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    var result = await couchDb.allDocs<Map<String, dynamic>>(
        GetAllDocsRequest(includeDocs: true), (value) => value);
    print(result.toJson((value) => value));
    expect(result.totalRows, isNotNull);
  });

  test('info()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    var result = await couchDb.info();
    expect(result, isNotNull);
    expect(result.dbName, equals(envDbName));
  });

  group("put() with newEdits=False", () {
    const id = "putNewEditsisfalse";
    test('with Rev should be success put', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      PutResponse putResponse = await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString("1-bb"),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);

      expect(putResponse.ok, isTrue);
    });
    test('without Rev should catch error', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      try {
        await couchDb.put(
            doc: Doc(id: id, model: {"name": "wgg", "no": 300}),
            newEdits: false);
      } catch (err) {
        expectAsync0(() => {expect(err, isInstanceOf<AdapterException>())})();
      }
    });

    test('empty revisions, create new history', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('1-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('2-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      Doc<Map<String, dynamic>>? doc = await couchDb.get(
          id: id, fromJsonT: (val) => val, meta: true, revs: true);
      expect(doc, isNotNull);
      expect(doc!.conflicts!.length, 1);
      expect(doc.revisions!.ids.length, 1);
      couchDb.delete(id: id, rev: Rev.fromString('2-a'));
    });

    test('with revision, link to existing', () async {
      final CouchdbAdapter couchDb = getCouchDbAdapter();
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('1-a'),
              model: {"name": "wgg", "no": 300}),
          newEdits: false);
      await couchDb.put(
          doc: Doc(
              id: id,
              rev: Rev.fromString('2-a'),
              model: {"name": "wgg", "no": 300},
              revisions: Revisions(start: 2, ids: ['a', 'a'])),
          newEdits: false);
      Doc<Map<String, dynamic>>? doc = await couchDb.get(
          id: id, fromJsonT: (val) => val, meta: true, revs: true);
      expect(doc, isNotNull);
      expect(doc!.conflicts, isNull);
      expect(doc.revisions!.ids.length, 2);
      couchDb.delete(id: id, rev: Rev.fromString('2-a'));
    });

    // test('put conflicts', () async {
    //   final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: "adish");
    //   PutResponse conflictResponse = await couchDb.put(
    //       doc: Doc(
    //           id: "put u mf",
    //           model: {"name": "berry-berry", "no": 888},
    //           rev: "1-d5ea00d10b2471cdbe3420293c980282"),
    //       newEdits: false,
    //       newRev: "2-testtest2");

    //   expect(conflictResponse.ok, isTrue);
    // });
  });

  test('get()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    PutResponse putResponse =
        await couchDb.put(doc: Doc(id: "test1", model: {}));
    expect(putResponse.ok, isTrue);

    Doc? doc1 = await couchDb.get(id: 'test1', fromJsonT: (v) => {});
    expect(doc1, isNotNull);

    Doc? doc2 = await couchDb.get(id: 'test3', fromJsonT: (v) => {});
    expect(doc2, isNull);
  });

  group('designDoc', () {
    final CouchdbAdapter couchdb = getCouchDbAdapter();
    setUp(() async {
      await couchdb.createIndex(indexFields: ['_id'], ddoc: "type_user_id");
      await couchdb.createIndex(indexFields: ['name'], ddoc: "type_user_name");
    });
    test('fetchDesignDoc()', () async {
      Doc<DesignDoc>? designDoc =
          await couchdb.fetchDesignDoc(id: "_design/type_user_name");
      print(designDoc?.toJson((value) => value.toJson()));
      expect(designDoc, isNotNull);
    });

    test('fetchAllDesignDocs()', () async {
      List<Doc<DesignDoc>?> designDoc = await couchdb.fetchAllDesignDocs();
      expect(designDoc.length, equals(2));
    });
  });

  test('delete()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    await couchDb.put(
        doc: Doc(id: "test", rev: Rev.fromString("1-a"), model: {}),
        newEdits: false);
    DeleteResponse deleteResponse =
        await couchDb.delete(id: "test", rev: Rev.fromString('1-a'));
    expect(deleteResponse.ok, true);
  });

  test('createIndex()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    IndexResponse indexResponse =
        await couchDb.createIndex(indexFields: ['_id']);
    print(indexResponse.toJson());
    expect(indexResponse.result, isNotNull);
  });

  test('find()', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    await couchDb.createIndex(indexFields: ['_id']);
    await couchDb.put(doc: Doc(id: "user_123", model: {}));
    FindResponse<Map<String, dynamic>> findResponse =
        await couchDb.find<Map<String, dynamic>>(
            FindRequest(selector: {
              '_id': {'\$regex': '^user'}
            }),
            (json) => json);
    print(findResponse.docs);
    expect(findResponse.docs.length > 0, isTrue);
  });

  test('EnsureFullCommit In CouchDB adish', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    EnsureFullCommitResponse ensureFullCommitResponse =
        await couchDb.ensureFullCommit();
    expect(ensureFullCommitResponse.ok, isTrue);
  });
  test('init', () async {
    var dbName = Uuid().v4();
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: dbName.toString());
    bool test = await couchDb.init();
    expect(test, true);

    bool destroy = await couchDb.destroy();
    expect(destroy, true);
  });

  test('delete db', () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter(dbName: "aawertyuytre");
    await couchDb.destroy();
  });

  test("change stream", () async {
    int count = 0;
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    await couchDb.put(doc: Doc(id: '1', model: {'name': 'ff'}));
    await couchDb.put(
        doc: Doc(id: '2', model: {'name': 'zz'}, rev: Rev.fromString('1-a')),
        newEdits: false);
    await couchDb.delete(id: '2', rev: Rev.fromString('1-a'));
    var fn = expectAsync1((changeResponse) {
      expect(changeResponse, isNotNull);
    });
    couchDb
        .changesStream(ChangeRequest(
            includeDocs: true,
            feed: ChangeFeed.normal,
            since: '0',
            style: "all_docs",
            heartbeat: 1000))
        .then((changesStream) {
      var listener = changesStream.listen(onHearbeat: () {
        ++count;
        print('heartneat $count');
        // if (count == 5) {
        //   fn();
        // }
      }, onResult: (event) {
        print('onResult: ${event.toJson()}');
      }, onComplete: (changeResponse) {
        print('onCompleted: ${changeResponse.toJson()}');
        fn(changeResponse);
      });
    });

    await Future.delayed(Duration(seconds: 3));
    await couchDb.put(doc: Doc(id: '3', model: {'name': 'zz'}));
  });

  Map<String, dynamic> json = {
    //"_id": "mMenuV3_2020-06-10T04:46:25.945Z",
    //"_rev": "525-bec841cd19a920a10dab9bb0c176e5c6",
    "subModule": {
      "addonGroup": [
        {
          "name": "Side Dish",
          "min": 0,
          "max": 2,
          "priority": null,
          "addonGroupType": "NORMAL",
          "stackable": true,
          "addons": [
            {
              "id": "2020-06-10T04:51:36.768Z",
              "name": "French Fries",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            },
            {
              "id": "2020-06-10T04:51:44.169Z",
              "name": "Mash Potato",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-10T04:52:01.496Z",
              "name": "Coleslaw",
              "name2": null,
              "price": {"amount": 0, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            }
          ],
          "_id": "addonGroup_2020-06-10T04:52:07.738Z_c2qtqw",
          "position": 5
        },
        {
          "name": "Stock P AG 1",
          "min": 1,
          "max": 5,
          "priority": null,
          "addonGroupType": "PRODUCT",
          "stackable": true,
          "addons": [
            {
              "id": "2020-06-12T14:21:50.170Z",
              "name": "Stock PA 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-12T09:11:05.303Z_s9kv6g",
              "variantCombination": []
            },
            {
              "id": "2020-06-12T14:21:50.173Z",
              "name": "Stock PA 2",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-12T09:11:15.986Z_149c98",
              "variantCombination": []
            }
          ],
          "_id": "addonGroup_2020-06-12T09:10:43.186Z_kqwtkn",
          "position": 3
        },
        {
          "name": "Stock P AG V 1",
          "min": 1,
          "max": 1,
          "priority": null,
          "addonGroupType": "PRODUCT",
          "stackable": false,
          "addons": [
            {
              "id": "2020-06-12T14:22:57.957Z",
              "name": "Stock P W 1 V 1",
              "name2": null,
              "price": {"amount": 0, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-12T09:22:48.208Z_238fhi",
              "variantCombination": [
                {
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z",
                  "selectionName": ["V1 1"],
                  "active": true,
                  "price": {"amount": 200, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
                  "selectionName": ["V1 2"],
                  "active": true,
                  "price": {"amount": 100, "currency": "MYR", "precision": 2}
                }
              ]
            },
            {
              "id": "2020-06-12T14:22:57.978Z",
              "name": "Stock P W 2 V 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-12T09:24:35.538Z_m4heqh",
              "variantCombination": [
                {
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:10.850Z",
                  "selectionName": ["V1 1", "V2 1"],
                  "active": true,
                  "price": {"amount": 100, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:18.378Z",
                  "selectionName": ["V1 1", "V2 2"],
                  "active": true,
                  "price": {"amount": 200, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:10.850Z",
                  "selectionName": ["V1 2", "V2 1"],
                  "active": true,
                  "price": {"amount": 300, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:18.378Z",
                  "selectionName": ["V1 2", "V2 2"],
                  "active": true,
                  "price": {"amount": 400, "currency": "MYR", "precision": 2}
                }
              ]
            },
            {
              "id": "2020-09-26T08:08:13.797Z",
              "name": "Test",
              "name2": "",
              "price": {"amount": 5, "currency": "MYR", "precision": 2},
              "productId": "product_2020-07-10T05:37:21.789Z_kg834q",
              "variantCombination": []
            },
            {
              "id": "2020-09-26T08:08:20.479Z",
              "name": "Stock P w PA 1",
              "name2": "",
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-12T09:12:11.180Z_5uz4fi",
              "variantCombination": []
            },
            {
              "id": "2020-09-26T08:12:30.735Z",
              "name": "Coffee",
              "name2": "",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-10T04:49:32.183Z_dvep6j",
              "variantCombination": [
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "selectionName": ["Hotss", "No Sugars"],
                  "active": true,
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "selectionName": ["Hotss", "Less Sugar"],
                  "active": true,
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "selectionName": ["Cold", "No Sugars"],
                  "active": true,
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "selectionName": ["Cold", "Less Sugar"],
                  "active": true,
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                }
              ]
            },
            {
              "id": "2020-09-26T08:12:38.501Z",
              "name": "Many Side Dish 1",
              "name2": "",
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-15T04:06:40.843Z_yor0yv",
              "variantCombination": []
            }
          ],
          "_id": "addonGroup_2020-06-12T14:22:58.746Z_dx66pe",
          "position": 4
        },
        {
          "name": "Side Dish Choice 1",
          "min": 1,
          "max": 2,
          "priority": "1",
          "addonGroupType": "NORMAL",
          "stackable": true,
          "addons": [
            {
              "id": "2020-06-15T04:07:05.001Z",
              "name": "Side Dish 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:07:35.584Z",
              "name": "Side Dish 2",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:08:38.150Z",
              "name": "Side Dish 3",
              "name2": null,
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            }
          ],
          "_id": "addonGroup_2020-06-15T04:07:39.661Z_h5v0wi",
          "position": 1
        },
        {
          "name": "Side Dish Choice 2",
          "min": 0,
          "max": 1,
          "priority": "2",
          "addonGroupType": "NORMAL",
          "stackable": false,
          "addons": [
            {
              "id": "2020-06-15T04:07:50.232Z",
              "name": "Side Dish 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:07:54.975Z",
              "name": "Side Dish 2",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:08:45.678Z",
              "name": "Side Dish 3",
              "name2": null,
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            }
          ],
          "_id": "addonGroup_2020-06-15T04:07:58.543Z_q0cg3e",
          "position": 2
        },
        {
          "name": "Side Dish Choice 3",
          "min": 1,
          "max": 1,
          "priority": "4",
          "addonGroupType": "NORMAL",
          "stackable": false,
          "addons": [
            {
              "id": "2020-06-15T04:08:09.015Z",
              "name": "Side Dish 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:08:12.951Z",
              "name": "Side Dish 2",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:08:52.894Z",
              "name": "Side Dish 3",
              "name2": null,
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2021-07-12T09:22:29.871Z",
              "name": "Side Dish41",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            }
          ],
          "_id": "addonGroup_2020-06-15T04:08:16.722Z_2msc20",
          "position": 0
        },
        {
          "name": "Side Dish Choice 4",
          "min": 1,
          "max": 1,
          "priority": "3",
          "addonGroupType": "NORMAL",
          "stackable": false,
          "addons": [
            {
              "id": "2020-06-15T04:08:26.654Z",
              "name": "Side Dish 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:08:30.095Z",
              "name": "Side Dish 2",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            },
            {
              "id": "2020-06-15T04:09:04.462Z",
              "name": "Side Dish 3",
              "name2": null,
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null
            }
          ],
          "_id": "addonGroup_2020-06-15T04:08:33.696Z_63o6vr",
          "position": 6
        },
        {
          "name": "variant addon",
          "addonGroupType": "PRODUCT",
          "min": 1,
          "max": 1,
          "stackable": false,
          "addons": [
            {
              "id": "2020-10-19T14:08:21.379Z",
              "name": "variant product 1",
              "name2": "",
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-10-19T14:07:55.873Z_abnhc4",
              "variantCombination": [
                {
                  "active": true,
                  "selectionName": ["V1 1"],
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z",
                  "codeSuffix": "c1",
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                },
                {
                  "active": true,
                  "selectionName": ["V1 2"],
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
                  "code": "c2",
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                }
              ]
            },
            {
              "id": "2020-10-19T14:08:29.058Z",
              "name": "variant product 2",
              "name2": "",
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-10-19T14:08:11.527Z_0bmtcm",
              "variantCombination": [
                {
                  "active": true,
                  "selectionName": ["V2 1"],
                  "combinationKey":
                      "variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:10.850Z",
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                },
                {
                  "active": true,
                  "selectionName": ["V2 2"],
                  "combinationKey":
                      "variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:18.378Z",
                  "price": {"amount": 0, "currency": "MYR", "precision": 2}
                }
              ]
            }
          ],
          "position": 7,
          "_id": "addonGroup_2020-10-19T14:08:30.947Z_60u7id"
        },
        {
          "name": "Fried Rice Side Dish",
          "addonGroupType": "PRODUCT",
          "min": 0,
          "max": 4,
          "stackable": true,
          "addons": [
            {
              "id": "2020-11-04T09:58:04.883Z",
              "name": "Side Dish Egg",
              "name2": "",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": "product_2020-11-04T09:53:32.039Z_o20erj",
              "variantCombination": [
                {
                  "combinationKey":
                      "variant_2020-11-04T09:55:00.779Z_dzyq7r/2020-11-04T09:54:21.598Z",
                  "selectionName": ["Hard Boiled Egg"],
                  "active": true,
                  "price": null
                },
                {
                  "combinationKey":
                      "variant_2020-11-04T09:55:00.779Z_dzyq7r/2020-11-04T09:54:32.708Z",
                  "selectionName": ["Fried Egg"],
                  "active": true,
                  "price": {"amount": 400, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-11-04T09:55:00.779Z_dzyq7r/2020-11-04T09:54:37.712Z",
                  "selectionName": ["Half Boild Egg"],
                  "active": true,
                  "price": null
                }
              ]
            },
            {
              "id": "2020-11-04T09:58:17.128Z",
              "name": "Side Dish Sausage",
              "name2": "",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": "product_2020-11-04T09:56:41.104Z_urhu28",
              "variantCombination": [
                {
                  "active": true,
                  "selectionName": ["Vienna Sausage"],
                  "combinationKey":
                      "variant_2020-11-04T09:57:00.082Z_q9p5pl/2020-11-04T09:56:45.701Z",
                  "price": null
                },
                {
                  "active": true,
                  "selectionName": ["Snail Sausage"],
                  "combinationKey":
                      "variant_2020-11-04T09:57:00.082Z_q9p5pl/2020-11-04T09:56:52.195Z",
                  "price": null
                }
              ]
            }
          ],
          "position": 8,
          "_id": "addonGroup_2020-11-04T09:58:21.193Z_t49p1f"
        },
        {
          "name": "Drink Choice",
          "addonGroupType": "PRODUCT",
          "min": 1,
          "max": 1,
          "stackable": false,
          "addons": [
            {
              "id": "2020-11-04T10:01:58.664Z",
              "name": "Coffee",
              "name2": "",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-10T04:49:32.183Z_dvep6j",
              "variantCombination": [
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "selectionName": ["Hotss", "No Sugars"],
                  "active": true,
                  "price": {"amount": 100, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "selectionName": ["Hotss", "Less Sugar"],
                  "active": true,
                  "price": {"amount": 200, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "selectionName": ["Cold", "No Sugars"],
                  "active": true,
                  "price": {"amount": 300, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "selectionName": ["Cold", "Less Sugar"],
                  "active": true,
                  "price": {"amount": 400, "currency": "MYR", "precision": 2}
                }
              ]
            },
            {
              "id": "2021-01-12T08:04:36.799Z",
              "name": "Tea",
              "name2": "",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": "product_2020-11-04T10:01:35.990Z_xz3ktc",
              "variantCombination": [
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "active": false,
                  "selectionName": ["No Sugars", "Hotss"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "active": true,
                  "selectionName": ["No Sugars", "Cold"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "active": true,
                  "selectionName": ["Less Sugar", "Hotss"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "active": true,
                  "selectionName": ["Less Sugar", "Cold"]
                }
              ]
            }
          ],
          "position": 9,
          "_id": "addonGroup_2020-11-04T10:02:01.109Z_htv3s7"
        },
        {
          "name": "sauce",
          "addonGroupType": "NORMAL",
          "min": 1,
          "max": 2,
          "stackable": true,
          "addons": [
            {
              "id": "2020-11-23T10:57:19.383Z",
              "name": "black pepper",
              "name2": "",
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            },
            {
              "id": "2020-11-23T10:57:31.967Z",
              "name": "cheese",
              "name2": "",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            }
          ],
          "position": 10,
          "_id": "addonGroup_2020-11-23T10:57:43.292Z_nqkfo8"
        },
        {
          "name": "Drink",
          "addonGroupType": "PRODUCT",
          "min": 1,
          "max": 1,
          "stackable": false,
          "addons": [
            {
              "id": "2021-02-26T09:16:46.254Z",
              "name": "Coffee",
              "name2": "",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "productId": "product_2020-06-10T04:49:32.183Z_dvep6j",
              "variantCombination": [
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "selectionName": ["Hotss", "No Sugars"],
                  "active": true,
                  "price": null
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "selectionName": ["Hotss", "Less Sugar"],
                  "active": true,
                  "price": {"amount": 200, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "selectionName": ["Cold", "No Sugars"],
                  "active": true,
                  "price": {"amount": 400, "currency": "MYR", "precision": 2}
                },
                {
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "selectionName": ["Cold", "Less Sugar"],
                  "active": true,
                  "price": null
                }
              ]
            },
            {
              "id": "2021-02-26T09:16:50.609Z",
              "name": "Tea",
              "name2": "",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": "product_2020-11-04T10:01:35.990Z_xz3ktc",
              "variantCombination": [
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "active": true,
                  "selectionName": ["No Sugars", "Hotss"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
                  "active": true,
                  "selectionName": ["No Sugars", "Cold"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "active": true,
                  "selectionName": ["Less Sugar", "Hotss"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
                  "active": true,
                  "selectionName": ["Less Sugar", "Cold"]
                }
              ]
            }
          ],
          "position": 0,
          "_id": "addonGroup_2021-02-26T09:17:02.971Z_3ierdm"
        },
        {
          "name": "dynamic group",
          "addons": [
            {
              "id": "2021-03-05T08:52:10.991Z",
              "name": "test 1",
              "name2": null,
              "price": {"amount": 0, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            },
            {
              "id": "2021-03-05T08:52:12.883Z",
              "name": "test 2",
              "name2": null,
              "price": {"amount": 0, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            },
            {
              "id": "2021-03-05T08:52:14.029Z",
              "name": "test 3",
              "name2": null,
              "price": {"amount": 0, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            }
          ],
          "min": 2,
          "max": 2,
          "addonGroupType": "DYNAMIC",
          "stackable": true,
          "position": 13,
          "_id": "addonGroup_2021-03-05T08:52:18.467Z_h3ru37"
        },
        {
          "name": "dynamic addon product",
          "addons": [
            {
              "id": "2021-03-08T09:27:21.088Z",
              "name": "dynamic 2",
              "name2": null,
              "price": {"amount": 600, "currency": "MYR", "precision": 2},
              "productId": "product_2021-03-05T08:04:32.319Z_1q7crv",
              "variantCombination": []
            },
            {
              "id": "2021-03-08T09:27:24.697Z",
              "name": "dynamic 1",
              "name2": null,
              "price": {"amount": 500, "currency": "MYR", "precision": 2},
              "productId": "product_2021-03-05T08:03:51.369Z_kjk9eq",
              "variantCombination": [
                {
                  "price": {"amount": 500, "currency": "MYR", "precision": 2},
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
                  "active": true,
                  "selectionName": ["Hotss"]
                },
                {
                  "price": {"amount": 600, "currency": "MYR", "precision": 2},
                  "combinationKey":
                      "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
                  "active": true,
                  "selectionName": ["Cold"]
                }
              ]
            }
          ],
          "min": 0,
          "max": 1,
          "addonGroupType": "PRODUCT",
          "stackable": false,
          "position": 13,
          "_id": "addonGroup_2021-03-08T09:27:25.581Z_3js3p0"
        },
        {
          "name": "variant code product addon",
          "addons": [
            {
              "id": "2021-03-10T13:46:43.883Z",
              "name": "variant product 1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": "product_2020-10-19T14:07:55.873Z_abnhc4",
              "variantCombination": [
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z",
                  "active": true,
                  "selectionName": ["V1 1"]
                },
                {
                  "price": null,
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
                  "active": true,
                  "selectionName": ["V1 2"]
                }
              ]
            }
          ],
          "min": 0,
          "max": 111,
          "addonGroupType": "PRODUCT",
          "stackable": false,
          "position": 14,
          "_id": "addonGroup_2021-03-10T13:46:53.878Z_ujnf8t"
        },
        {
          "name": "Test addon",
          "addons": [
            {
              "id": "2021-06-24T05:44:17.660Z",
              "name": "addon1",
              "name2": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            },
            {
              "id": "2021-06-24T05:44:27.702Z",
              "name": "addon 2",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            }
          ],
          "min": 0,
          "max": 1,
          "addonGroupType": "NORMAL",
          "stackable": false,
          "position": 15,
          "_id": "addonGroup_2021-06-24T05:44:32.977Z_ueqdf6"
        },
        {
          "name": "test product addon group",
          "addons": [
            {
              "id": "2021-06-24T05:45:31.017Z",
              "name": "test addon",
              "name2": null,
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "productId": "product_2021-06-24T05:45:01.467Z_wemggy",
              "variantCombination": []
            }
          ],
          "min": 1,
          "max": 1,
          "addonGroupType": "PRODUCT",
          "stackable": false,
          "position": 0,
          "_id": "addonGroup_2021-06-24T05:45:47.547Z_3c7dmf"
        },
        {
          "name": "Test Addon 1",
          "addons": [
            {
              "id": "2021-07-12T09:23:13.062Z",
              "name": "Addon 1",
              "name2": null,
              "price": {"amount": 0, "currency": "MYR", "precision": 2},
              "productId": null,
              "variantCombination": null,
              "inventoryBindings": []
            }
          ],
          "min": 1,
          "max": 1,
          "addonGroupType": "NORMAL",
          "stackable": false,
          "position": 17,
          "_id": "addonGroup_2021-07-12T09:23:25.946Z_btx8vf"
        }
      ],
      "catalog": [
        {
          "name": "Takeaway",
          "productAvailable": ["product_2020-06-10T07:38:35.341Z_h47mwl"],
          "override": {"product": {}, "addon": {}},
          "_id": "catalog_2020-06-10T07:39:16.937Z_eyoaqz",
          "inclusiveTaxes": [
            {"systemCode": "SST", "inclusive": true}
          ]
        },
        {
          "name": "In House Delivery",
          "productAvailable": [
            "product_2020-06-10T07:38:52.102Z_qoeq9z",
            "product_2020-06-11T09:00:09.406Z_9u42fv",
            "product_2020-11-04T09:52:35.341Z_0r9ac1",
            "product_2020-06-10T04:49:32.183Z_dvep6j",
            "product_2021-01-11T06:12:32.810Z_guvg8c",
            "product_2020-08-17T13:26:45.957Z_gmp3y2"
          ],
          "override": {"product": {}, "addon": {}},
          "_id": "catalog_2020-06-10T07:39:27.925Z_3wbfuj",
          "inclusiveTaxes": [
            {"systemCode": "SST", "inclusive": true}
          ]
        },
        {
          "name": "Restaurant",
          "productAvailable": [
            "product_2020-06-10T14:26:52.248Z_kurq1v",
            "product_2020-06-11T09:00:09.406Z_9u42fv",
            "product_2020-07-10T05:37:21.789Z_kg834q",
            "product_2020-06-10T04:49:32.183Z_dvep6j",
            "product_2021-01-11T06:12:32.810Z_guvg8c"
          ],
          "override": {"product": {}, "addon": {}},
          "_id": "catalog_2020-06-10T14:27:06.472Z_5xuegy",
          "inclusiveTaxes": null
        },
        {
          "name": "Test",
          "productAvailable": [
            "product_2020-06-10T07:38:52.102Z_qoeq9z",
            "product_2020-06-12T14:23:25.721Z_p8rb1t",
            "product_2020-11-04T09:53:32.039Z_o20erj",
            "product_2020-11-04T09:56:41.104Z_urhu28",
            "product_2020-11-04T09:52:35.341Z_0r9ac1"
          ],
          "override": {"product": {}, "addon": {}},
          "_id": "catalog_2020-08-07T02:02:59.061Z_uva7lt"
        },
        {
          "name": "Takeaway clone",
          "productAvailable": [
            "product_2020-06-10T07:38:35.341Z_h47mwl",
            "product_2020-06-11T09:00:09.406Z_9u42fv",
            "product_2020-06-12T09:22:48.208Z_238fhi"
          ],
          "override": {
            "product": {
              "product_2020-06-12T09:22:48.208Z_238fhi": [
                {
                  "type": "PRODUCT_VARIANT_PRICE",
                  "combinationKey":
                      "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
                  "value": {"amount": 200, "currency": "MYR", "precision": 2}
                }
              ]
            },
            "addon": {}
          },
          "_id": "catalog_2020-08-24T06:59:48.552Z_0jo865"
        },
        {
          "name": "Pickup",
          "productAvailable": [
            "product_2020-09-14T05:11:26.481Z_0qivss",
            "product_2020-11-04T09:52:35.341Z_0r9ac1",
            "product_2020-06-10T04:49:32.183Z_dvep6j",
            "product_2021-01-11T06:12:32.810Z_guvg8c",
            "product_2020-08-17T13:26:45.957Z_gmp3y2",
            "product_2020-06-11T09:00:09.406Z_9u42fv",
            "product_2021-03-05T08:04:32.319Z_1q7crv",
            "product_2021-03-05T08:03:51.369Z_kjk9eq",
            "product_2020-11-04T09:56:41.104Z_urhu28",
            "product_2020-10-19T14:07:55.873Z_abnhc4"
          ],
          "override": {"product": {}, "addon": {}},
          "_id": "catalog_2020-09-14T05:12:25.675Z_gx0a22",
          "inclusiveTaxes": [
            {"systemCode": "SST", "inclusive": true}
          ]
        },
        {
          "name": "Special",
          "productAvailable": [
            "product_2020-09-14T05:11:45.190Z_sbjmyh",
            "product_2020-06-11T09:00:09.406Z_9u42fv",
            "product_2020-11-04T09:52:35.341Z_0r9ac1",
            "product_2021-01-11T06:12:32.810Z_guvg8c"
          ],
          "override": {"product": {}, "addon": {}},
          "_id": "catalog_2020-09-14T05:12:42.823Z_d5qwpt",
          "inclusiveTaxes": null
        },
        {
          "name": "Food Panda",
          "productAvailable": ["product_2020-11-24T06:40:04.700Z_hdslv0"],
          "override": {
            "product": {
              "product_2020-11-24T06:40:04.700Z_hdslv0": [
                {
                  "type": "PRODUCT_PRICE",
                  "value": {"amount": 800, "currency": "MYR", "precision": 2}
                }
              ]
            },
            "addon": {}
          },
          "inclusiveTaxes": [
            {"systemCode": "SST", "inclusive": true}
          ],
          "_id": "catalog_2020-11-24T06:40:21.776Z_xro5rm"
        },
        {
          "name": "Table 1",
          "productAvailable": [
            "product_2020-11-24T06:47:59.980Z_yc8yjc",
            "product_2021-01-11T06:12:32.810Z_guvg8c",
            "product_2020-06-10T04:49:32.183Z_dvep6j",
            "product_2020-11-04T10:01:35.990Z_xz3ktc",
            "product_2020-11-04T09:56:41.104Z_urhu28",
            "product_2020-11-04T09:52:35.341Z_0r9ac1",
            "product_2020-07-10T05:37:21.789Z_kg834q",
            "product_2020-08-17T13:26:45.957Z_gmp3y2",
            "product_2020-06-11T09:00:09.406Z_9u42fv",
            "product_2021-03-05T08:04:32.319Z_1q7crv",
            "product_2021-03-05T08:03:51.369Z_kjk9eq",
            "product_2021-06-24T05:46:18.152Z_urb2l8",
            "product_2020-11-24T06:48:11.760Z_d0pyd9"
          ],
          "override": {"product": {}, "addon": {}},
          "inclusiveTaxes": [
            {"systemCode": "SST", "inclusive": true}
          ],
          "_id": "catalog_2020-11-24T06:48:26.011Z_dtnlr8"
        },
        {
          "name": "Table 2",
          "productAvailable": [
            "product_2020-11-24T06:48:11.760Z_d0pyd9",
            "product_2020-06-10T04:49:32.183Z_dvep6j",
            "product_2021-01-11T06:12:32.810Z_guvg8c",
            "product_2020-11-04T10:01:35.990Z_xz3ktc"
          ],
          "override": {"product": {}, "addon": {}},
          "inclusiveTaxes": [
            {"systemCode": "SST", "inclusive": true}
          ],
          "_id": "catalog_2020-11-24T06:48:36.155Z_udt4fo"
        },
        {
          "name": "feedme delivery",
          "productAvailable": [
            "product_2021-02-02T09:38:51.547Z_tg7qdp",
            "product_2020-08-17T13:26:45.957Z_gmp3y2"
          ],
          "override": {"product": {}, "addon": {}},
          "inclusiveTaxes": null,
          "_id": "catalog_2021-02-02T09:39:07.465Z_jg4m62"
        }
      ],
      "category": [
        {
          "name": "Food",
          "_id": "category_2020-06-10T04:48:59.957Z_pial9w",
          "position": 1
        },
        {
          "name": "Drink",
          "_id": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "position": 0
        },
        {
          "name": "Other",
          "position": 2,
          "_id": "category_2020-08-26T11:38:28.638Z_ibb7no"
        },
        {
          "name": "variant product 1",
          "position": 3,
          "_id": "category_2020-10-19T14:07:39.248Z_4cf3wa"
        }
      ],
      "product": [
        {
          "code": "F1",
          "name": "Chicken Chop",
          "name2": "",
          "price": {"amount": 1000, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-08-26T11:38:28.638Z_ibb7no",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": ["addonGroup_2020-06-10T04:52:07.738Z_c2qtqw"],
          "variantUsed": ["variant_2020-06-10T04:52:34.856Z_bohjid"],
          "variantCombination": [
            {
              "combinationKey":
                  "variant_2020-06-10T04:52:34.856Z_bohjid/2020-06-10T04:52:25.471Z",
              "active": true,
              "selectionName": ["BBQs"],
              "codeSuffix": "BB",
              "price": {"amount": 1000, "currency": "MYR", "precision": 2}
            },
            {
              "combinationKey":
                  "variant_2020-06-10T04:52:34.856Z_bohjid/2020-06-10T04:52:29.752Z",
              "active": true,
              "selectionName": ["Black Pepper"],
              "codeSuffix": "BP",
              "price": {"amount": 1000, "currency": "MYR", "precision": 2}
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-10T04:49:23.541Z_9jlbr1"
        },
        {
          "code": "D1",
          "name": "Coffee s",
          "name2": "",
          "price": {"amount": 0, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "description":
              "Base: Jasmine Rice \n底料：白饭\nSauces: Spicy Hawaii, Cheese Sauce\n酱汁：夏威夷辣味酱，芝士酱\nSides: Corn, Japanese Cucumber, Cherry Tomatoes, Mango, Seaweed Salad, Soft-Boiled Egg\n配料：玉米，日本黄瓜，小番茄，芒果，海藻，溏心蛋\nToppings: Furikake, Tobikko, Seaweed Flake\n佐料：日本香松粉，鱼卵，海苔丝\nProtein: Salmon (Raw), Tuna (Raw), Sushi Ebi\n主食：三文鱼，鲔鱼，寿司虾 （生/熟）",
          "orderFrom": "ALL",
          "addonGroupUsed": ["addonGroup_2020-06-15T04:08:16.722Z_2msc20"],
          "variantUsed": [
            "variant_2020-06-10T04:49:51.362Z_t0c25d",
            "variant_2020-06-10T04:50:23.138Z_bynfjo"
          ],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["Hotss", "No Sugars"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
              "codeSuffix": "HN",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "code": "D1HN"
            },
            {
              "active": true,
              "selectionName": ["Hotss", "Less Sugar"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
              "codeSuffix": "HL",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "code": "D1HL"
            },
            {
              "active": true,
              "selectionName": ["Cold", "No Sugars"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
              "codeSuffix": "CN",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "code": "D1CN"
            },
            {
              "active": true,
              "selectionName": ["Cold", "Less Sugar"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
              "codeSuffix": "CL",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "code": "ABCD"
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "thumbnail":
              "https://firebasestorage.googleapis.com/v0/b/feedme-dev-4c3ef.appspot.com/o/menu%2F5ee065a11d46e8001b990cfa%2Fproduct_2020-06-10T04%3A49%3A32.183Z_dvep6j?alt=media&token=4feee6a6-be40-470a-9e59-1941bb83e79b",
          "_id": "product_2020-06-10T04:49:32.183Z_dvep6j",
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "addonProductBinding": []
        },
        {
          "code": "T1",
          "name": "Takeaway 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-08-26T11:38:28.638Z_ibb7no",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-10T07:38:35.341Z_h47mwl"
        },
        {
          "code": "F10",
          "name": "In House Delivery",
          "name2": "",
          "price": {"amount": 1000, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-10T07:38:52.102Z_qoeq9z",
          "openPrice": false,
          "taxes": []
        },
        {
          "code": "F2",
          "name": "Restaurant 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-10T14:26:52.248Z_kurq1v"
        },
        {
          "code": "ZX1",
          "name": "Pay Test1",
          "name2": "",
          "price": {"amount": 5, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "thumbnail": null,
          "_id": "product_2020-06-11T09:00:09.406Z_9u42fv",
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "addonProductBinding": []
        },
        {
          "code": "S1",
          "name": "Stock PA 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-12T09:11:05.303Z_s9kv6g"
        },
        {
          "code": "S2",
          "name": "Stock PA 2",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-12T09:11:15.986Z_149c98"
        },
        {
          "code": "S3",
          "name": "Stock P w PA 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": ["addonGroup_2020-06-12T09:10:43.186Z_kqwtkn"],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-12T09:12:11.180Z_5uz4fi"
        },
        {
          "code": "S4",
          "name": "Stock P W 1 V 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-08-26T11:38:28.638Z_ibb7no",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": ["variant_2020-06-12T09:23:04.822Z_0ilstn"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["V1 1"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z",
              "codeSuffix": null,
              "price": {"amount": 100, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "selectionName": ["V1 2"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
              "codeSuffix": "V2",
              "price": {"amount": 200, "currency": "MYR", "precision": 2}
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-12T09:22:48.208Z_238fhi"
        },
        {
          "code": "S5",
          "name": "Stock P W 2 V 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [],
          "variantUsed": [
            "variant_2020-06-12T09:23:04.822Z_0ilstn",
            "variant_2020-06-12T09:23:20.644Z_rrokif"
          ],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["V1 1", "V2 1"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:10.850Z",
              "codeSuffix": "11",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["V1 1", "V2 2"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:18.378Z",
              "codeSuffix": "12",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["V1 2", "V2 1"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:10.850Z",
              "codeSuffix": "21",
              "price": null
            },
            {
              "active": false,
              "selectionName": ["V1 2", "V2 2"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z/variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:18.378Z",
              "codeSuffix": "22",
              "price": {"amount": 400, "currency": "MYR", "precision": 2}
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-12T09:24:35.538Z_m4heqh"
        },
        {
          "code": "S6",
          "name": "Stock Final P",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [
            "addonGroup_2020-06-12T09:10:43.186Z_kqwtkn",
            "addonGroup_2020-06-12T14:22:58.746Z_dx66pe"
          ],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-12T14:23:25.721Z_p8rb1t"
        },
        {
          "code": "AG1",
          "name": "Many Side Dish 1",
          "name2": "",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "perXUnit": null,
          "unit": null,
          "productType": "ALA_CARTE",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "description": null,
          "orderFrom": "ALL",
          "addonGroupUsed": [
            "addonGroup_2020-06-15T04:07:39.661Z_h5v0wi",
            "addonGroup_2020-06-15T04:07:58.543Z_q0cg3e",
            "addonGroup_2020-06-15T04:08:16.722Z_2msc20",
            "addonGroup_2020-06-15T04:08:33.696Z_63o6vr"
          ],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "thumbnail": null,
          "_id": "product_2020-06-15T04:06:40.843Z_yor0yv"
        },
        {
          "code": "TTTT",
          "name": "Test",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 5, "currency": "MYR", "precision": 2},
          "description": "",
          "thumbnail":
              "https://firebasestorage.googleapis.com/v0/b/feedme-dev-4c3ef.appspot.com/o/menu%2F5ee065a11d46e8001b990cfa%2Fproduct_2020-07-10T05%3A37%3A21.789Z_kg834q?alt=media&token=ecce1ac2-0138-4afd-85ea-3a96d7bbd9f1",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "_id": "product_2020-07-10T05:37:21.789Z_kg834q",
          "openPrice": false
        },
        {
          "code": "CODE2",
          "name": "Code test2",
          "name2": "",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 0, "currency": "MYR", "precision": 2},
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "_id": "product_2020-08-17T13:26:45.957Z_gmp3y2",
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "addonProductBinding": []
        },
        {
          "code": "PU1",
          "name": "Pick up 1 new",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 1000, "currency": "MYR", "precision": 2},
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "_id": "product_2020-09-14T05:11:26.481Z_0qivss",
          "openPrice": false
        },
        {
          "code": "SP1",
          "name": "Special catalog 1",
          "name2": "",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 1000, "currency": "MYR", "precision": 2},
          "description":
              "Set include:\n\nMeat X 2\nVegetable Set A x 1\nVegetable Set B x 1\nMushroom Set x 1\nFuzhuk set x 1\nBall Set A x1\nBall Set B x 1\nTofu Set x 1\nMee (3 in 1) x 1\nSauce x 3\nSoup x 1\nPot x 1\n4-Head Fire x 1\nSteamboat Bag x 1\nSoap Spoon Set x 1\nScissors x 1\nLighter x 1\nWet Tissue x 3\nBowl x 3\nFork & Spoon Set x 3",
          "thumbnail":
              "https://firebasestorage.googleapis.com/v0/b/feedme-dev-4c3ef.appspot.com/o/menu%2F5ee065a11d46e8001b990cfa%2Fproduct_2020-09-14T05%3A11%3A45.190Z_sbjmyh?alt=media&token=5f3d168d-e158-4dae-8e30-7b62bca91927",
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "_id": "product_2020-09-14T05:11:45.190Z_sbjmyh",
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ]
        },
        {
          "code": "t33",
          "name": "normal product with variant product addon",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2020-10-19T14:08:30.947Z_60u7id"],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "_id": "product_2020-10-19T14:06:56.085Z_fevrt4"
        },
        {
          "code": "t23",
          "name": "variant product with variant product addon",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2020-10-19T14:08:30.947Z_60u7id"],
          "variantUsed": ["variant_2020-06-12T09:23:04.822Z_0ilstn"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["V1 1"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z",
              "codeSuffix": "",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["V1 2"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
              "codeSuffix": "",
              "price": null
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "_id": "product_2020-10-19T14:07:15.206Z_m6pzqe"
        },
        {
          "code": "t32",
          "name": "variant product 1",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2021-03-10T13:46:53.878Z_ujnf8t"],
          "variantUsed": ["variant_2020-06-12T09:23:04.822Z_0ilstn"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["V1 1"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:56.655Z",
              "codeSuffix": "code suffix",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["V1 2"],
              "combinationKey":
                  "variant_2020-06-12T09:23:04.822Z_0ilstn/2020-06-12T09:22:58.626Z",
              "code": "new code",
              "price": null
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "_id": "product_2020-10-19T14:07:55.873Z_abnhc4"
        },
        {
          "code": "t34",
          "name": "variant product 2",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": ["variant_2020-06-12T09:23:20.644Z_rrokif"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["V2 1"],
              "combinationKey":
                  "variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:10.850Z",
              "codeSuffix": "",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["V2 2"],
              "combinationKey":
                  "variant_2020-06-12T09:23:20.644Z_rrokif/2020-06-12T09:23:18.378Z",
              "codeSuffix": "",
              "price": null
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "_id": "product_2020-10-19T14:08:11.527Z_0bmtcm"
        },
        {
          "code": "FR1",
          "name": "Fried Rice",
          "name2": "",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 500, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "noSst": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [
            "addonGroup_2020-11-04T09:58:21.193Z_t49p1f",
            "addonGroup_2020-06-10T04:52:07.738Z_c2qtqw",
            "addonGroup_2021-03-08T09:27:25.581Z_3js3p0"
          ],
          "variantUsed": ["variant_2020-11-04T09:59:32.193Z_3uq7x5"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["Tom Yam Fried Rice"],
              "combinationKey":
                  "variant_2020-11-04T09:59:32.193Z_3uq7x5/2020-11-04T09:59:09.024Z",
              "codeSuffix": "",
              "price": {"amount": 700, "currency": "MYR", "precision": 2},
              "inventoryBindings": []
            },
            {
              "active": true,
              "selectionName": ["Egg Fried Rice"],
              "combinationKey":
                  "variant_2020-11-04T09:59:32.193Z_3uq7x5/2020-11-04T09:59:15.968Z",
              "codeSuffix": "",
              "price": null,
              "inventoryBindings": []
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "inventoryBindings": [
            {
              "type": "RECIPE",
              "id": "recipe_2020-11-04T09:51:14.088Z_qsqfto",
              "amount": {"amount": 1, "precision": 0}
            }
          ],
          "_id": "product_2020-11-04T09:52:35.341Z_0r9ac1",
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "addonProductBinding": []
        },
        {
          "code": "FE1",
          "name": "Side Dish Egg",
          "name2": "",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 200, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "noSst": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": ["variant_2020-11-04T09:55:00.779Z_dzyq7r"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["Hard Boiled Egg"],
              "combinationKey":
                  "variant_2020-11-04T09:55:00.779Z_dzyq7r/2020-11-04T09:54:21.598Z",
              "codeSuffix": "",
              "price": null,
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2020-11-04T09:50:51.979Z_io1t8g",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "selectionName": ["Fried Egg"],
              "combinationKey":
                  "variant_2020-11-04T09:55:00.779Z_dzyq7r/2020-11-04T09:54:32.708Z",
              "codeSuffix": "",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2020-11-04T09:50:51.979Z_io1t8g",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "selectionName": ["Half Boild Egg"],
              "combinationKey":
                  "variant_2020-11-04T09:55:00.779Z_dzyq7r/2020-11-04T09:54:37.712Z",
              "codeSuffix": "",
              "price": null,
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2020-11-04T09:50:51.979Z_io1t8g",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2020-11-04T09:50:51.979Z_io1t8g",
              "amount": {"amount": 1, "precision": 0}
            }
          ],
          "_id": "product_2020-11-04T09:53:32.039Z_o20erj"
        },
        {
          "code": "S1",
          "name": "Side Dish Sausage",
          "name2": "",
          "category": "category_2020-06-10T04:48:59.957Z_pial9w",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 200, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "noSst": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2020-11-23T10:57:43.292Z_nqkfo8"],
          "variantUsed": ["variant_2020-11-04T09:57:00.082Z_q9p5pl"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["Vienna Sausage"],
              "combinationKey":
                  "variant_2020-11-04T09:57:00.082Z_q9p5pl/2020-11-04T09:56:45.701Z",
              "codeSuffix": "",
              "price": null,
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2020-11-04T09:52:54.085Z_r5bggz",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "selectionName": ["Snail Sausage"],
              "combinationKey":
                  "variant_2020-11-04T09:57:00.082Z_q9p5pl/2020-11-04T09:56:52.195Z",
              "codeSuffix": "",
              "price": null,
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2020-11-04T09:52:54.085Z_r5bggz",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "_id": "product_2020-11-04T09:56:41.104Z_urhu28"
        },
        {
          "code": "T1",
          "name": "Tea",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 200, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "noSst": false,
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [
            "variant_2020-06-10T04:50:23.138Z_bynfjo",
            "variant_2020-06-10T04:49:51.362Z_t0c25d"
          ],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["No Sugars", "Hotss"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
              "codeSuffix": "",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["No Sugars", "Cold"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:05.496Z",
              "codeSuffix": "",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["Less Sugar", "Hotss"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
              "codeSuffix": "",
              "price": null
            },
            {
              "active": true,
              "selectionName": ["Less Sugar", "Cold"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z/variant_2020-06-10T04:50:23.138Z_bynfjo/2020-06-10T04:50:08.569Z",
              "codeSuffix": "",
              "price": null
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "_id": "product_2020-11-04T10:01:35.990Z_xz3ktc"
        },
        {
          "code": "FP1",
          "name": "Food Panda",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 500, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "inventoryBindings": null,
          "_id": "product_2020-11-24T06:40:04.700Z_hdslv0"
        },
        {
          "code": "T1",
          "name": "Table 1",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 500, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description":
              "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "inventoryBindings": null,
          "_id": "product_2020-11-24T06:47:59.980Z_yc8yjc",
          "addonProductBinding": []
        },
        {
          "code": "T2",
          "name": "Table 2",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 500, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "_id": "product_2020-11-24T06:48:11.760Z_d0pyd9",
          "addonProductBinding": []
        },
        {
          "code": "S1",
          "name": "Set Meal",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2021-02-26T09:17:02.971Z_3ierdm"],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "_id": "product_2021-01-11T06:12:32.810Z_guvg8c"
        },
        {
          "code": "fm1",
          "name": "FeedMe",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 500, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "_id": "product_2021-02-02T09:38:51.547Z_tg7qdp"
        },
        {
          "code": "dy1",
          "name": "dynamic 1",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 500, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2021-03-05T08:52:18.467Z_h3ru37"],
          "variantUsed": ["variant_2020-06-10T04:49:51.362Z_t0c25d"],
          "variantCombination": [
            {
              "active": true,
              "selectionName": ["Hotss"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "codeSuffix": "",
              "code": null,
              "price": {"amount": 500, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "selectionName": ["Cold"],
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "codeSuffix": "",
              "code": null,
              "price": {"amount": 600, "currency": "MYR", "precision": 2}
            }
          ],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
              "amount": {"amount": 1, "precision": 0}
            }
          ],
          "advanceAddon": [
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:18.857Z",
              "price": {"amount": 200, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:18.857Z",
              "price": {"amount": 300, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:25.587Z",
              "price": {"amount": 200, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:25.587Z",
              "price": {"amount": 300, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:31.292Z",
              "price": {"amount": 200, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:31.292Z",
              "price": {"amount": 300, "currency": "MYR", "precision": 2}
            }
          ],
          "_id": "product_2021-03-05T08:03:51.369Z_kjk9eq",
          "addonProductBinding": [
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:10.991Z",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:10.991Z",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 2, "precision": 0}
                }
              ]
            },
            {
              "active": false,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:12.883Z"
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:12.883Z",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 2, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:45.424Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:14.029Z",
              "price": {"amount": 200, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "combinationKey":
                  "variant_2020-06-10T04:49:51.362Z_t0c25d/2020-06-10T04:49:48.535Z",
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:14.029Z",
              "price": {"amount": 300, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 2, "precision": 0}
                }
              ]
            }
          ]
        },
        {
          "code": "d2",
          "name": "dynamic 2",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 600, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail":
              "https://firebasestorage.googleapis.com/v0/b/feedme-dev-4c3ef.appspot.com/o/menu%2F5ee065a11d46e8001b990cfa%2Fproduct_2021-03-05T08%3A04%3A32.319Z_1q7crv?alt=media&token=15365b21-5342-49b8-9ab2-f35cb67bd472",
          "addonGroupUsed": ["addonGroup_2021-03-05T08:52:18.467Z_h3ru37"],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y",
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
              "amount": {"amount": 1, "precision": 0}
            }
          ],
          "advanceAddon": [
            {
              "active": true,
              "combinationKey": null,
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:18.857Z",
              "price": {"amount": 400, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey": null,
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:25.587Z",
              "price": {"amount": 400, "currency": "MYR", "precision": 2}
            },
            {
              "active": true,
              "combinationKey": null,
              "addonKey":
                  "addonGroup_2021-03-05T08:01:45.789Z_rchd5i/2021-03-05T08:01:31.292Z",
              "price": {"amount": 400, "currency": "MYR", "precision": 2}
            }
          ],
          "_id": "product_2021-03-05T08:04:32.319Z_1q7crv",
          "addonProductBinding": [
            {
              "active": true,
              "combinationKey": null,
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:10.991Z",
              "price": {"amount": 400, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "combinationKey": null,
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:12.883Z",
              "price": {"amount": 400, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            },
            {
              "active": true,
              "combinationKey": null,
              "addonKey":
                  "addonGroup_2021-03-05T08:52:18.467Z_h3ru37/2021-03-05T08:52:14.029Z",
              "price": {"amount": 400, "currency": "MYR", "precision": 2},
              "inventoryBindings": [
                {
                  "type": "SKU",
                  "id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
                  "amount": {"amount": 1, "precision": 0}
                }
              ]
            }
          ]
        },
        {
          "code": "test addon",
          "name": "test addon",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 200, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2021-06-24T05:44:32.977Z_ueqdf6"],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "addonProductBinding": [],
          "_id": "product_2021-06-24T05:45:01.467Z_wemggy"
        },
        {
          "code": "test product addon",
          "name": "test product addon",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 0, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": ["addonGroup_2021-06-24T05:45:47.547Z_3c7dmf"],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "addonProductBinding": [],
          "_id": "product_2021-06-24T05:46:18.152Z_urb2l8"
        },
        {
          "code": "UP1",
          "name": "Unit Product 1",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": "gram",
          "perXUnit": "100",
          "price": {"amount": 100, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "addonProductBinding": [],
          "_id": "product_2021-07-12T07:47:44.477Z_kyt6eq"
        },
        {
          "code": "TTTTT1",
          "name": "T",
          "name2": "",
          "category": "category_2020-06-10T04:49:03.915Z_ir6ktc",
          "orderFrom": "ALL",
          "unit": null,
          "perXUnit": null,
          "price": {"amount": 0, "currency": "MYR", "precision": 2},
          "openPrice": false,
          "taxes": [
            {"systemCode": "SST", "taxCode": "SV"}
          ],
          "description": "",
          "thumbnail": null,
          "addonGroupUsed": [],
          "variantUsed": [],
          "variantCombination": [],
          "schedulerUsed": null,
          "takeawayUsed": null,
          "inventoryBindings": null,
          "addonProductBinding": [],
          "_id": "product_2021-07-12T09:02:09.942Z_nh73w8"
        }
      ],
      "scheduler": [
        {
          "name": "Test Scheduler",
          "timePeriod": [
            {"start": "13:00", "end": "16:14"}
          ],
          "weekDay": [],
          "repeat": "daily",
          "_id": "scheduler_2020-08-24T05:07:13.540Z_s6uh2z"
        }
      ],
      "variant": [
        {
          "name": "Temperature",
          "options": [
            {"id": "2020-06-10T04:49:45.424Z", "name": "Hotss"},
            {"id": "2020-06-10T04:49:48.535Z", "name": "Cold"}
          ],
          "_id": "variant_2020-06-10T04:49:51.362Z_t0c25d"
        },
        {
          "name": "Sugar",
          "options": [
            {"id": "2020-06-10T04:50:05.496Z", "name": "No Sugars"},
            {"id": "2020-06-10T04:50:08.569Z", "name": "Less Sugar"}
          ],
          "_id": "variant_2020-06-10T04:50:23.138Z_bynfjo"
        },
        {
          "name": "Sauce",
          "options": [
            {"id": "2020-06-10T04:52:25.471Z", "name": "BBQs"},
            {"id": "2020-06-10T04:52:29.752Z", "name": "Black Pepper"}
          ],
          "_id": "variant_2020-06-10T04:52:34.856Z_bohjid"
        },
        {
          "name": "Stock V  1",
          "options": [
            {"id": "2020-06-12T09:22:56.655Z", "name": "V1 1"},
            {"id": "2020-06-12T09:22:58.626Z", "name": "V1 2"}
          ],
          "_id": "variant_2020-06-12T09:23:04.822Z_0ilstn"
        },
        {
          "name": "Stock V 2",
          "options": [
            {"id": "2020-06-12T09:23:10.850Z", "name": "V2 1"},
            {"id": "2020-06-12T09:23:18.378Z", "name": "V2 2"}
          ],
          "_id": "variant_2020-06-12T09:23:20.644Z_rrokif"
        },
        {
          "name": "asd",
          "options": [],
          "_id": "variant_2020-08-22T07:28:40.349Z_587z1n"
        },
        {
          "name": "23",
          "options": [
            {"id": "2020-08-22T07:43:34.740Z", "name": "23"}
          ],
          "_id": "variant_2020-08-22T07:43:39.888Z_5aiqr8"
        },
        {
          "name": "Type of Egg",
          "options": [
            {"id": "2020-11-04T09:54:21.598Z", "name": "Hard Boiled Egg"},
            {"id": "2020-11-04T09:54:32.708Z", "name": "Fried Egg"},
            {"id": "2020-11-04T09:54:37.712Z", "name": "Half Boild Egg"}
          ],
          "_id": "variant_2020-11-04T09:55:00.779Z_dzyq7r"
        },
        {
          "name": "Type of Sausage",
          "options": [
            {"id": "2020-11-04T09:56:45.701Z", "name": "Vienna Sausage"},
            {"id": "2020-11-04T09:56:52.195Z", "name": "Snail Sausage"}
          ],
          "_id": "variant_2020-11-04T09:57:00.082Z_q9p5pl"
        },
        {
          "name": "Type of Fried Rice",
          "options": [
            {"id": "2020-11-04T09:59:09.024Z", "name": "Tom Yam Fried Rice"},
            {"id": "2020-11-04T09:59:15.968Z", "name": "Egg Fried Rice"}
          ],
          "_id": "variant_2020-11-04T09:59:32.193Z_3uq7x5"
        }
      ],
      "takeaway": [
        {
          "name": "takeaway",
          "price": {"amount": 200, "currency": "MYR", "precision": 2},
          "_id": "takeaway_2020-07-27T07:29:21.069Z_2tyu8y"
        }
      ],
      "unit": [
        {
          "name": "gram",
          "abbrev": "g",
          "precision": 0,
          "measurements": [
            {
              "id": "2021-04-19T11:01:48.736Z",
              "name": "kilogram",
              "abbrev": "kg",
              "conversion": {"amount": 1000, "precision": 0}
            },
            {
              "id": "2021-04-28T05:09:20.501Z",
              "name": "spoon",
              "abbrev": "spoon",
              "conversion": {"amount": 50, "precision": 0}
            }
          ],
          "_id": "unit_2020-11-04T09:49:29.085Z_ghdr8d"
        },
        {
          "name": "piece",
          "abbrev": "p",
          "precision": 0,
          "measurements": [],
          "_id": "unit_2020-11-04T09:50:41.397Z_z8gouj"
        },
        {
          "name": "ml",
          "abbrev": "ml",
          "precision": 0,
          "measurements": [
            {
              "id": "2021-04-28T05:03:38.404Z",
              "name": "bottle",
              "abbrev": "bottle",
              "conversion": {"amount": 750, "precision": 0}
            },
            {
              "id": "2021-04-28T05:04:43.097Z",
              "name": "cup",
              "abbrev": "cup",
              "conversion": {"amount": 300, "precision": 0}
            }
          ],
          "_id": "unit_2021-04-28T05:04:12.173Z_yv5b9u"
        }
      ],
      "sku": [
        {
          "code": "r1",
          "name": "rice",
          "unit": {
            "name": "gram",
            "abbrev": "g",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-19T11:01:48.736Z",
                "name": "kilogram",
                "abbrev": "kg",
                "conversion": {"amount": 1000, "precision": 0}
              },
              {
                "id": "2021-04-28T05:09:20.501Z",
                "name": "spoon",
                "abbrev": "spoon",
                "conversion": {"amount": 50, "precision": 0}
              }
            ],
            "_id": "unit_2020-11-04T09:49:29.085Z_ghdr8d"
          },
          "trackingMeasurement": null,
          "_id": "sku_2020-11-04T09:49:42.220Z_cfnc7m"
        },
        {
          "code": "e1",
          "name": "egg",
          "unit": {
            "name": "piece",
            "abbrev": "p",
            "precision": 0,
            "measurements": [],
            "_id": "unit_2020-11-04T09:50:41.397Z_z8gouj"
          },
          "trackingMeasurement": null,
          "_id": "sku_2020-11-04T09:50:51.979Z_io1t8g"
        },
        {
          "code": "s1",
          "name": "sausage",
          "unit": {
            "name": "piece",
            "abbrev": "p",
            "precision": 0,
            "measurements": [],
            "_id": "unit_2020-11-04T09:50:41.397Z_z8gouj"
          },
          "trackingMeasurement": null,
          "_id": "sku_2020-11-04T09:52:54.085Z_r5bggz"
        },
        {
          "code": "d1",
          "name": "dynamic",
          "unit": {
            "name": "piece",
            "abbrev": "p",
            "precision": 0,
            "measurements": [],
            "_id": "unit_2020-11-04T09:50:41.397Z_z8gouj"
          },
          "trackingMeasurement": null,
          "_id": "sku_2021-03-08T05:36:55.371Z_frdh9j",
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2020-11-04T09:50:51.979Z_io1t8g",
              "amount": {"amount": 1, "precision": 0}
            }
          ]
        },
        {
          "code": "A",
          "name": "A",
          "unit": {
            "name": "gram",
            "abbrev": "g",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-19T11:01:48.736Z",
                "name": "kilogram",
                "abbrev": "kg",
                "conversion": {"amount": 1000, "precision": 0}
              },
              {
                "id": "2021-04-28T05:09:20.501Z",
                "name": "spoon",
                "abbrev": "spoon",
                "conversion": {"amount": 50, "precision": 0}
              }
            ],
            "_id": "unit_2020-11-04T09:49:29.085Z_ghdr8d"
          },
          "trackingMeasurement": null,
          "inventoryBindings": [],
          "_id": "sku_2021-04-23T05:58:58.267Z_2bd8fy"
        },
        {
          "code": "A1",
          "name": "A1",
          "unit": {
            "name": "gram",
            "abbrev": "g",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-19T11:01:48.736Z",
                "name": "kilogram",
                "abbrev": "kg",
                "conversion": {"amount": 1000, "precision": 0}
              },
              {
                "id": "2021-04-28T05:09:20.501Z",
                "name": "spoon",
                "abbrev": "spoon",
                "conversion": {"amount": 50, "precision": 0}
              }
            ],
            "_id": "unit_2020-11-04T09:49:29.085Z_ghdr8d"
          },
          "trackingMeasurement": null,
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2021-04-23T05:58:58.267Z_2bd8fy",
              "amount": {"amount": 1, "precision": 0}
            }
          ],
          "_id": "sku_2021-04-23T05:59:08.740Z_rboz38"
        },
        {
          "code": "A2",
          "name": "A2",
          "unit": {
            "name": "gram",
            "abbrev": "g",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-19T11:01:48.736Z",
                "name": "kilogram",
                "abbrev": "kg",
                "conversion": {"amount": 1000, "precision": 0}
              },
              {
                "id": "2021-04-28T05:09:20.501Z",
                "name": "spoon",
                "abbrev": "spoon",
                "conversion": {"amount": 50, "precision": 0}
              }
            ],
            "_id": "unit_2020-11-04T09:49:29.085Z_ghdr8d"
          },
          "trackingMeasurement": null,
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2021-04-23T05:58:58.267Z_2bd8fy",
              "amount": {"amount": 1, "precision": 0}
            }
          ],
          "_id": "sku_2021-04-23T05:59:17.496Z_14bfo5"
        },
        {
          "code": "milk",
          "name": "milk",
          "unit": {
            "name": "ml",
            "abbrev": "ml",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-28T05:03:38.404Z",
                "name": "bottle",
                "abbrev": "bottle",
                "conversion": {"amount": 750, "precision": 0}
              },
              {
                "id": "2021-04-28T05:04:43.097Z",
                "name": "cup",
                "abbrev": "cup",
                "conversion": {"amount": 300, "precision": 0}
              }
            ],
            "_id": "unit_2021-04-28T05:04:12.173Z_yv5b9u"
          },
          "trackingMeasurement": "2021-04-28T05:03:38.404Z",
          "inventoryBindings": [],
          "_id": "sku_2021-04-28T05:05:12.287Z_tessw0"
        },
        {
          "code": "yogurt",
          "name": "yogurt",
          "unit": {
            "name": "ml",
            "abbrev": "ml",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-28T05:03:38.404Z",
                "name": "bottle",
                "abbrev": "bottle",
                "conversion": {"amount": 750, "precision": 0}
              },
              {
                "id": "2021-04-28T05:04:43.097Z",
                "name": "cup",
                "abbrev": "cup",
                "conversion": {"amount": 300, "precision": 0}
              }
            ],
            "_id": "unit_2021-04-28T05:04:12.173Z_yv5b9u"
          },
          "trackingMeasurement": "2021-04-28T05:03:38.404Z",
          "inventoryBindings": [
            {
              "type": "SKU",
              "id": "sku_2021-04-28T05:05:12.287Z_tessw0",
              "amount": {"amount": 1, "precision": 0},
              "measurement": {
                "id": "2021-04-28T05:03:38.404Z",
                "name": "bottle",
                "abbrev": "bottle",
                "conversion": {"amount": 750000, "precision": 3}
              }
            },
            {
              "type": "SKU",
              "id": "sku_2021-04-28T05:05:40.022Z_zv7yzr",
              "amount": {"amount": 2, "precision": 0},
              "measurement": {
                "id": "2021-04-28T05:09:20.501Z",
                "name": "spoon",
                "abbrev": "spoon",
                "conversion": {"amount": 50, "precision": 0}
              }
            }
          ],
          "_id": "sku_2021-04-28T05:05:25.440Z_hpub83"
        },
        {
          "code": "sugar",
          "name": "sugar",
          "unit": {
            "name": "gram",
            "abbrev": "g",
            "precision": 0,
            "measurements": [
              {
                "id": "2021-04-19T11:01:48.736Z",
                "name": "kilogram",
                "abbrev": "kg",
                "conversion": {"amount": 1000, "precision": 0}
              },
              {
                "id": "2021-04-28T05:09:20.501Z",
                "name": "spoon",
                "abbrev": "spoon",
                "conversion": {"amount": 50, "precision": 0}
              }
            ],
            "_id": "unit_2020-11-04T09:49:29.085Z_ghdr8d"
          },
          "trackingMeasurement": "2021-04-28T05:09:20.501Z",
          "inventoryBindings": [],
          "_id": "sku_2021-04-28T05:05:40.022Z_zv7yzr"
        }
      ],
      "recipe": [
        {
          "name": "fried rice",
          "contains": [
            {
              "type": "SKU",
              "id": "sku_2020-11-04T09:50:51.979Z_io1t8g",
              "amount": {"amount": 1, "precision": 0}
            },
            {
              "type": "SKU",
              "id": "sku_2020-11-04T09:49:42.220Z_cfnc7m",
              "amount": {"amount": 2, "precision": 0},
              "measurement": {
                "id": "2021-04-19T11:01:48.736Z",
                "name": "kilogram",
                "abbrev": "kg",
                "conversion": {"amount": 1000, "precision": 0}
              }
            }
          ],
          "_id": "recipe_2020-11-04T09:51:14.088Z_qsqfto"
        }
      ]
    },
    "updatedAt": "2021-07-12T09:23:25.946Z",
    "type_mMenuV3": true,
    "masterCatalogSetting": {"inclusiveTaxes": []}
  };

  test("change stream 2", () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    couchDb
        .changesStream(
            ChangeRequest(feed: ChangeFeed.continuous, includeDocs: true))
        .then((value) => value.listen(
                onResult: expectAsync1((result) {
              print(result);
            }, count: 3)));

    await couchDb.put(doc: Doc(id: "a", model: {}));

    await couchDb.put(
        doc: Doc<Map<String, dynamic>>(
            id: "mMenuV3_2020-06-10T04:46:25.945Z",
            rev: Rev.fromString("525-bec841cd19a920a10dab9bb0c176e5c6"),
            model: json),
        newEdits: false);

    await couchDb.put(
        doc: Doc<Map<String, dynamic>>(
            id: "mMenuV3_2020-06-10T04:46:25.945Z",
            rev: Rev.fromString("525-bec841cd19a920a10dab9bb0c176e5c6"),
            model: json));
  });

  test("change stream timeout", () async {
    final CouchdbAdapter couchDb = getCouchDbAdapter();
    final fn = expectAsync1((result) {
      print(result);
    });
    couchDb
        .changesStream(ChangeRequest(
            feed: ChangeFeed.longpoll, includeDocs: true, timeout: 300))
        .then((value) => value.listen(onResult: fn));
    await Future.delayed(Duration(seconds: 1000));
    await couchDb.put(doc: Doc(id: "a", model: {}));
  });
}
