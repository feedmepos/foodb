import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

void main() async {
  test("time needed to run OpenStore()", () async {
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    Store store = await openStore();
    stopwatch.stop();
    print(stopwatch.elapsedMilliseconds);
    expect(store, isNotNull);
  });

  test("time needed to get box", () async {
    Stopwatch stopwatch = new Stopwatch();
    Store store = await openStore();
    stopwatch.start();
    Box box = store.box<DocObject>();
    stopwatch.stop();
    print(stopwatch.elapsedMilliseconds);
    expect(store, isNotNull);
  });

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
}
