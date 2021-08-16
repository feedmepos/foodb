import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/common/doc.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  test("_generateView", () async {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);
    await adapter.put(doc: Doc(id: 'id', model: {"name": "charlies", "no": 1}));
    await adapter.put(doc: Doc(id: 'id2', model: {"name": "ants", "no": 2}));
    // adapter.db.put(adapter.viewMetaTableName,
    //     id: "_all_docs__all_docs", object: {"lastSeq": 0});
    await adapter.allDocs(GetAllDocsRequest(), (json) => json);

    Map<String, dynamic>? doc = await adapter.db
        .get(adapter.viewTableName("_all_docs__all_docs"), id: "id");
    print(doc.toString());
    expect(doc, isNotNull);

    Map<String, dynamic>? doc2 = await adapter.db
        .get(adapter.viewTableName("_all_docs__all_docs"), id: "id2");
    print(doc2.toString());
    expect(doc2, isNotNull);
  });
}
