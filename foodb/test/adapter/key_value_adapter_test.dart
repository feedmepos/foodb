import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/in_memory_database.dart';
import 'package:foodb/adapter/key_value_adapter.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  test("_generateView", () {
    var db = InMemoryDatabase();
    var adapter = KeyValueAdapter(dbName: 'test', db: db);
  });
}
