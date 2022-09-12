import 'package:foodb/foodb.dart';
import 'package:test/test.dart';

void main() {
  test('websocket client', () async {
    final client = Foodb.websocket(
      dbName: 'restaurant_1',
      baseUri: Uri.parse('ws://127.0.0.1'),
    );
    final doc = await client.get(id: 'bill_1', fromJsonT: (v) => v);
    print(doc);
  });
}
