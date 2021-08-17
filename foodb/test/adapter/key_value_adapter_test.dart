import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/common/doc.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  getMemoryAdapter() {
    return KeyValueAdapter(dbName: 'test', db: InMemoryDatabase());
  }

  test("_generateView", () {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);
  });

  test('put & get', () async {
    final memoryDb = getMemoryAdapter();
    await memoryDb.put(doc: Doc(id: 'foo1', model: {'bar': 'foo'}));
    await memoryDb.put(doc: Doc(id: 'foo2', model: {'a': 'b'}));
    await memoryDb.put(
        doc: Doc(
            id: 'foo2',
            model: {'bar': 'foo'},
            rev: '1-92eff9dda44cb8003ee13990782580ff'));
    var doc1 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo1', fromJsonT: (v) => v);
    var doc2 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo2', fromJsonT: (v) => v);
    var doc3 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo3', fromJsonT: (v) => v);
    print(doc1?.toJson((value) => value));
    print(doc2?.toJson((value) => value));
    print(doc3?.toJson((value) => value));
    expect(doc1, isNotNull);
    expect(doc2, isNotNull);
    expect(doc3, isNull);
  });

  test('leaf docs', () async {
    final memoryDb = getMemoryAdapter();
    var res1 = await memoryDb.put(doc: Doc(id: 'foo1', model: {'a': 'b'}));
    var res2 = await memoryDb.put(
        doc: Doc(id: 'foo1', model: {'c': 'd'}, rev: res1.rev));
    await memoryDb.put(doc: Doc(id: 'foo1', model: {'e': 'f'}, rev: res2.rev));
    // await memoryDb.put(doc: Doc(id: 'foo1', model: {"hello": "world"}));
    await memoryDb.put(doc: Doc(id: 'foo3', model: {'a': 'b'}));
    await memoryDb.put(doc: Doc(id: 'foo4', model: {'a': 'b'}));
    await memoryDb.put(doc: Doc(id: 'foo5', model: {'a': 'b'}));
    print(await memoryDb.db.tableSize(memoryDb.docTableName));
    var docHistory = await memoryDb.getHistory('foo1');
    docHistory?.leafDocs.forEach((element) {
      print(element.toJson((value) => value));
    });
  });
}
