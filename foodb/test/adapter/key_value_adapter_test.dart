import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/methods/view.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/rev.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['IN_MEMORY_DB_NAME'] as String;

  getMemoryAdapter() {
    // return KeyValueAdapter(dbName: dbName, db: InMemoryDatabase());
  }

  group('allDocs', () {
    var adapter = getMemoryAdapter();

    setUp(() async {
      adapter = getMemoryAdapter();
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "a",
              rev: Rev.fromString("1-a"),
              model: {"name": "a", "no": 999}),
          newEdits: false);
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "b",
              rev: Rev.fromString("1-b"),
              model: {"name": "b", "no": 999}),
          newEdits: false);
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "c",
              rev: Rev.fromString("1-c"),
              model: {"name": "c", "no": 999}),
          newEdits: false);
    });
    test("check _generateView by create a, b, c and then delete/update a, b",
        () async {
      GetViewResponse<Map<String, dynamic>> docs = await adapter
          .allDocs<Map<String, dynamic>>(GetViewRequest(), (json) => json);
      print(docs.toJson((value) => value));
      expect(docs.rows.length, equals(3));

      await adapter.delete(id: "a", rev: Rev.fromString("1-a"));
      await adapter.put(
          doc: Doc<Map<String, dynamic>>(
              id: "b",
              rev: Rev.fromString("1-b"),
              model: {"name": "a", "no": 999}));

      GetViewResponse<Map<String, dynamic>> docsAfterChange =
          await adapter.allDocs(GetViewRequest(), (json) => json);
      print(docsAfterChange.toJson((value) => value));
      expect(docsAfterChange.rows.length, equals(2));
    });

    test("check allDocs with startKey and endKey", () async {
      GetViewResponse<Map<String, dynamic>> docs = await adapter.allDocs(
          GetViewRequest(startkey: "a", endkey: "b\uffff"), (json) => json);
      print(docs.toJson((value) => value));
      expect(docs.rows.length, equals(2));
    });

    test("allDocs after over 100 put doc", () async {
      final adapter = getMemoryAdapter();
      List<String> list = [
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z'
      ];
      for (String i in list) {
        for (int y = 0; y < 5; y++) {
          String id2 = "$i$y";
          for (int x = 0; x < 10; x++) {
            await adapter.put(
                doc: Doc(
                    id: id2,
                    model: {"name": "wth", "no": 99},
                    rev: Rev.fromString("$y-$x")),
                newEdits: false);
          }
        }
      }

      for (int y = 0; y < 5; y++) {
        String id2 = "l$y";
        for (int x = 0; x < 10; x++) {
          await adapter.put(
              doc: Doc(
                  id: id2,
                  model: {"name": "wth", "no": 99},
                  rev: Rev.fromString("$y-$x")),
              newEdits: false);
        }
      }
      GetViewResponse getAllDocs = await adapter.allDocs(
          GetViewRequest(startkey: "l", endkey: "l\uffff"), (json) => json);
      expect(getAllDocs.rows.length, equals(5));
      expect(getAllDocs.totalRows, equals(130));
    });
  });
}
