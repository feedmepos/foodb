import 'package:foodb/foodb.dart';
import 'package:test/test.dart';

// need local couchdb to run test
// void main() {
//   test('foodb.couchdb get success/missing/exception', () async {
//     final client = Foodb.couchdb(
//       dbName: 'restaurant_61a9935e94eb2c001d618bc3',
//       baseUri: Uri.parse('http://admin:ieXZW5@127.0.0.1:6984'),
//     );
//     final doc = await client.get(
//         id: '_local/pos-v5-to-local-test', fromJsonT: (v) => v);
//     expect(doc, isNot(null));
//     final invalidDoc =
//         await client.get(id: '_local/invalid-doc', fromJsonT: (v) => v);
//     expect(invalidDoc, null);

//     final invalidClient = Foodb.couchdb(
//       dbName: 'restaurant_61a9935e94eb2c001d618bc3',
//       baseUri: Uri.parse('http://127.0.0.1:1233'),
//     );
//     expect(() async {
//       await invalidClient.get(
//           id: '_local/pos-v5-to-local-test', fromJsonT: (v) => v);
//     }, throwsException);
//   });
// }
