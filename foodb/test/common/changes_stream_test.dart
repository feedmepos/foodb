import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/foodb.dart';

import '../adapter/adapter_test.dart';

void main() {
  test("changes stream", () async {
    final db = await getCouchDbAdapter("adish");
    db.changesStreamString(
        ChangeRequest(since: "now", feed: ChangeFeed.longpoll)).then((value) =>
    value.listen(expectAsync1((event){
      print(event);
    }, count: 3)));

    PutResponse put = await db.put(doc: Doc(id: "A", model: {}));
    expect(put.ok, isTrue);
  });
}
