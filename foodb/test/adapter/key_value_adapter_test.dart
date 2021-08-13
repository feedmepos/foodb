import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/common/doc.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  getMemeoryAdapter() {
    return KeyValueAdapter(dbName: 'test', db: InMemoryDatabase());
  }

  test("_generateView", () {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);
  });

  test('put & get', () async {
    final KeyValueAdapter memoryDb = getMemeoryAdapter();
    await memoryDb.put(doc: Doc(id: 'foo1', model: {'bar': 'foo'}));
    await memoryDb.put(doc: Doc(id: 'foo2', model: {'a': 'b'}));
    await memoryDb.put(
        doc: new Doc(id: 'foo2', model: {'bar': 'foo'}),
        newEdits: false,
        newRev: '2-dadadada');
    var doc1 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo1', fromJsonT: (v) => v);
    var doc2 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo2', fromJsonT: (v) => v);
    var doc3 = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo3', fromJsonT: (v) => v);
    expect(doc1, isNotNull);
    expect(doc2, isNotNull);
    expect(doc3, isNull);
  });
}
