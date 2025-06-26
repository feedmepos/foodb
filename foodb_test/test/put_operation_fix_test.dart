import 'dart:async';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';

void main() {
  test('Basic put operation works after race condition fix', () async {
    var adapter = KeyValueAdapter.inMemory();
    var db = Foodb.keyvalue(
        dbName: 'test-put-fix',
        keyValueDb: adapter);
    await db.initDb();
    
    // Test that basic put operations work
    final putResponse = await db.put(doc: Doc(id: 'test-1', model: {'value': 42}));
    expect(putResponse.ok, isTrue);
    expect(putResponse.id, equals('test-1'));
    expect(putResponse.rev, isNotNull);
    
    // Test that we can retrieve the document
    final doc = await db.get(id: 'test-1', fromJsonT: (json) => json);
    expect(doc.id, equals('test-1'));
    expect(doc.model['value'], equals(42));
    
    print('✅ Put operation and retrieval work correctly after race condition fix');
  });

  test('Change stream still works after race condition fix', () async {
    var adapter = KeyValueAdapter.inMemory();
    var db = Foodb.keyvalue(
        dbName: 'test-change-stream-fix',
        keyValueDb: adapter);
    await db.initDb();
    
    var changeReceived = false;
    final completer = Completer<void>();
    
    // Subscribe to changes
    final changeStream = await db.changesStream(
      ChangeRequest(feed: ChangeFeed.continuous),
      onResult: (result) {
        if (result.id == 'change-test') {
          changeReceived = true;
          completer.complete();
        }
      },
    );
    
    // Wait a moment for subscription to be active
    await Future.delayed(Duration(milliseconds: 50));
    
    // Create a document
    await db.put(doc: Doc(id: 'change-test', model: {'data': 'test'}));
    
    // Wait for change notification
    await completer.future.timeout(Duration(seconds: 2));
    
    await changeStream.cancel();
    
    expect(changeReceived, isTrue, reason: 'Change notification should be received after transaction commits');
    print('✅ Change stream notifications work correctly after race condition fix');
  });
}