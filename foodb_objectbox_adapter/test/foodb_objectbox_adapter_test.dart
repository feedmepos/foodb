import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';

void main() async {
  // test("time needed to run OpenStore()", () async {
  //   Stopwatch stopwatch = new Stopwatch();
  //   stopwatch.start();
  //   Store store = await openStore();
  //   stopwatch.stop();
  //   print(stopwatch.elapsedMilliseconds);
  //   expect(store, isNotNull);
  // });

  // test("time needed to get box", () async {
  //   Stopwatch stopwatch = new Stopwatch();
  //   Store store = await openStore();
  //   stopwatch.start();
  //   Box box = store.box<DocObject>();
  //   stopwatch.stop();
  //   print(stopwatch.elapsedMilliseconds);
  //   expect(store, isNotNull);
  // });

  test("put(), get()", () async {
    ObjectBox objectBox = new ObjectBox();
    await objectBox
        .put(DocDataType(), key: "1", object: {"name": "1", "id": 2});
    Map<String, dynamic>? doc = await objectBox.get(DocDataType(), key: "1");
    print(doc);
    expect(doc, isNotNull);
    expect(doc, {"name": "1", "id": 2});

    await objectBox
        .put(DocDataType(), key: "1", object: {"name": "2", "id": 3});
    Map<String, dynamic>? doc2 = await objectBox.get(DocDataType(), key: "1");
    print(doc2);
    expect(doc2, isNotNull);
    expect(doc2, {"name": "2", "id": 3});
  });

  test("last(), tableSize()", () async {
    ObjectBox objectBox = new ObjectBox();
    await objectBox.deleteTable(DocDataType());
    await objectBox
        .put(DocDataType(), key: "2", object: {"name": "1", "id": 2});
    await objectBox
        .put(DocDataType(), key: "3", object: {"name": "1", "id": 2});
    await objectBox
        .put(DocDataType(), key: "1", object: {"name": "1", "id": 2});
    MapEntry<String, dynamic>? doc = await objectBox.last(DocDataType());
    expect(doc, isNotNull);
    expect(doc?.key, "3");

    int size = await objectBox.tableSize(DocDataType());
    expect(size, equals(3));
  });

  test("read(), delete()", () async {
    ObjectBox objectBox = new ObjectBox();
    await objectBox.deleteTable(DocDataType());
    await objectBox
        .put(DocDataType(), key: "2", object: {"name": "1", "id": 2});
    await objectBox
        .put(DocDataType(), key: "3", object: {"name": "1", "id": 2});
    await objectBox
        .put(DocDataType(), key: "1", object: {"name": "1", "id": 2});
    ReadResult readResult =
        await objectBox.read(DocDataType(), startkey: "2", endkey: "3\uffff");
    readResult.docs.forEach((key, value) {
      print(key);
      print(value);
    });
    expect(readResult.docs.length, equals(2));
    expect(readResult.totalRows, 3);

    await objectBox.delete(DocDataType(), key: "3");
    Map<String, dynamic>? doc = await objectBox.get(DocDataType(), key: "3");
    expect(doc, isNull);
  });

  test('put() sequence', () async {
    ObjectBox objectBox = new ObjectBox();
    await objectBox.deleteTable(SequenceDataType());
    await objectBox.put(SequenceDataType(), key: "2", object: {"name": "a"});
    Map<String, dynamic>? doc =
        await objectBox.get(SequenceDataType(), key: "2");
    print(doc);
    expect(doc, isNotNull);

    await objectBox.put(SequenceDataType(), key: "11", object: {"name": "a"});

    MapEntry<String, dynamic>? map = await objectBox.last(SequenceDataType());
    expect(map?.key, "11");
  });

  test("deleteDatbase()", () async {
    ObjectBox objectBox = new ObjectBox();
    await objectBox.put(SequenceDataType(), key: "1", object: {"name": "123"});
    await objectBox.put(DocDataType(), key: "1", object: {"name": "123"});
    await objectBox.deleteDatabase();
    int result = await objectBox.tableSize(SequenceDataType());
    expect(result, equals(0));
    int result2 = await objectBox.tableSize(DocDataType());
    expect(result2, equals(0));
  });

  test("bulkdocs performance", () async {
    KeyValueAdapter keyValueAdapter =
        new KeyValueAdapter(dbName: 'test', db: ObjectBox());
    await keyValueAdapter.destroy();
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    BulkDocResponse bulkDocResponse = await keyValueAdapter.bulkDocs(body: [
      Doc(id: "1", model: {"name": 1}),
      Doc(id: "2", model: {"name": 1}),
      Doc(id: "3", model: {"name": 3}),
      Doc(id: "4", model: {"name": 1}),
      Doc(id: "5", model: {"name": 1}),
      Doc(id: "6", model: {"name": 3})
    ], newEdits: true);
    stopwatch.stop();
    print(stopwatch.elapsedMilliseconds);
    expect(bulkDocResponse.putResponses.length, 6);
    expect(bulkDocResponse.putResponses[0].ok, true);
    expect(bulkDocResponse.putResponses[1].ok, true);
    expect(bulkDocResponse.putResponses[2].ok, true);
    expect(bulkDocResponse.putResponses[3].ok, true);
    expect(bulkDocResponse.putResponses[4].ok, true);
    expect(bulkDocResponse.putResponses[5].ok, true);
  });
  group("delete vs delete many", () {
    ObjectBox objectBox = new ObjectBox();

    setUp(() async {
      await objectBox.deleteDatabase();
      await objectBox.put(DocDataType(), key: "1", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "2", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "3", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "4", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "5", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "6", object: {"name": "1"});
    });
    test("delete", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox.delete(DocDataType(), key: "1");
      await objectBox.delete(DocDataType(), key: "2");
      await objectBox.delete(DocDataType(), key: "3");
      await objectBox.delete(DocDataType(), key: "4");
      await objectBox.delete(DocDataType(), key: "5");
      await objectBox.delete(DocDataType(), key: "6");
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 0);
    });
    test("deleteMany", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox
          .deleteMany(DocDataType(), keys: ["1", "2", "3", "4", "5", "6"]);
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 0);
    });
  });

  group("insert vs insert many", () {
    ObjectBox objectBox = new ObjectBox();

    setUp(() async {
      await objectBox.deleteDatabase();
    });
    test("insert", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox.insert(DocDataType(), key: "1", object: {"name": "1"});
      await objectBox.insert(DocDataType(), key: "2", object: {"name": "1"});
      await objectBox.insert(DocDataType(), key: "3", object: {"name": "1"});
      await objectBox.insert(DocDataType(), key: "4", object: {"name": "1"});
      await objectBox.insert(DocDataType(), key: "5", object: {"name": "1"});
      await objectBox.insert(DocDataType(), key: "6", object: {"name": "1"});
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 6);
    });
    test("insertMany", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox.insertMany(DocDataType(), objects: {
        "1": {"name": "1"},
        "2": {"name": "1"},
        "3": {"name": "1"},
        "4": {"name": "1"},
        "5": {"name": "1"},
        "6": {"name": "1"}
      });
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 6);
    });
  });
  group("put vs put many", () {
    ObjectBox objectBox = new ObjectBox();

    setUp(() async {
      await objectBox.deleteDatabase();
    });
    test("put", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox.put(DocDataType(), key: "1", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "2", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "3", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "4", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "5", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "6", object: {"name": "1"});
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 6);
    });
    test("putMany", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox.putMany(DocDataType(), objects: {
        "1": {"name": "1"},
        "2": {"name": "1"},
        "3": {"name": "1"},
        "4": {"name": "1"},
        "5": {"name": "1"},
        "6": {"name": "1"}
      });
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 6);
    });
  });

  group("get vs get many", () {
    ObjectBox objectBox = new ObjectBox();

    setUp(() async {
      await objectBox.deleteDatabase();
      await objectBox.put(DocDataType(), key: "1", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "2", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "3", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "4", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "5", object: {"name": "1"});
      await objectBox.put(DocDataType(), key: "6", object: {"name": "1"});
    });
    test("get", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      await objectBox.get(DocDataType(), key: "1");
      await objectBox.get(DocDataType(), key: "2");
      await objectBox.get(DocDataType(), key: "3");
      await objectBox.get(DocDataType(), key: "4");
      await objectBox.get(DocDataType(), key: "5");
      await objectBox.get(DocDataType(), key: "6");
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      ReadResult readResult = await objectBox.read(DocDataType());
      expect(readResult.docs.length, 6);
    });
    test("getMany", () async {
      Stopwatch stopwatch = new Stopwatch();
      stopwatch.start();
      Map<String, dynamic>? map = await objectBox
          .getMany(DocDataType(), keys: ["1", "2", "3", "4", "5", "6"]);
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds);
      expect(map.length, 6);
    });
  });

  test('changeStream with limit', () async {
    ObjectBox objectBox = new ObjectBox();
    await objectBox.deleteDatabase();

    final objectBoxAdapter = KeyValueAdapter(dbName: "adish", db: objectBox);
    await objectBoxAdapter.bulkDocs(newEdits: true, body: [
      Doc(id: "1", model: {"name": "1"}),
      Doc(id: "2", model: {"name": "2"}),
      Doc(id: "3", model: {"name": "3"})
    ]);
    var fn =expectAsync1((result){
        expect(result, isNotNull);
    });
    final changeStream =
        await objectBoxAdapter.changesStream(ChangeRequest(limit:1,feed: ChangeFeed.normal));
    changeStream.listen(onResult: expectAsync1((data){
      print(data);
    },count: 1), onComplete: (result) {print("check $result"); fn(result);});
  });
}
