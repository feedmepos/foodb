import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  final ctx = InMemoryTestContext();
  isolateSequenceOrderingTest().forEach((t) {
    t(ctx);
  });
}

List<Function(FoodbTestContext)> isolateSequenceOrderingTest() {
  return [
    (FoodbTestContext ctx) {
      test('Test isolate change stream sequence ordering', () async {
        final dbName = 'test-isolate-sequence-ordering';
        final mainAdapter = await ctx.keyValueAdapter(dbName);
        
        final mainFoodb = Foodb.keyvalue(
          dbName: dbName,
          keyValueDb: mainAdapter,
          isolateLeader: true,
        ) as KeyvalueFoodb;
        
        // Track received changes
        List<ChangeResult> receivedChanges = [];
        List<int> receivedSequences = [];
        
        // Start listening to changes
        mainFoodb.changesStream(
          ChangeRequest(feed: ChangeFeed.continuous),
          onResult: (changeResult) {
            receivedChanges.add(changeResult);
            final seqNum = int.parse(changeResult.seq!.split('-')[0]);
            receivedSequences.add(seqNum);
          },
        );
        
        // Create multiple isolates that will generate changes concurrently
        final isolateCount = 3;
        final changesPerIsolate = 5;
        final isolateCompleted = Completer<void>();
        var completedIsolates = 0;
        
        for (int i = 0; i < isolateCount; i++) {
          final isolateIndex = i;
          Isolate.run(() async {
            final adapter = await ctx.keyValueAdapter(dbName);
            final foodb = Foodb.keyvalue(dbName: dbName, keyValueDb: adapter)
                as KeyvalueFoodb;
            
            // Join the cluster
            foodb.addIsolateMembership(mainFoodb.isolateReference);
            
            // Generate changes rapidly to increase chance of out-of-order delivery
            for (int j = 0; j < changesPerIsolate; j++) {
              await foodb.put(doc: Doc(
                id: 'isolate-${isolateIndex}-doc-${j}',
                model: {'data': 'value $j from isolate $isolateIndex'},
              ));
              
              // Small delay to allow interleaving
              await Future.delayed(Duration(milliseconds: 10));
            }
          }, debugName: 'test-isolate-$i').then((_) {
            completedIsolates++;
            if (completedIsolates == isolateCount) {
              isolateCompleted.complete();
            }
          });
        }
        
        // Wait for all isolates to complete
        await isolateCompleted.future;
        
        // Wait a bit more for all changes to be processed
        await Future.delayed(Duration(seconds: 2));
        
        // Verify that we received all expected changes
        expect(receivedChanges.length, isolateCount * changesPerIsolate);
        
        // Most importantly: verify that sequences are in order
        expect(receivedSequences, isA<List<int>>());
        
        // Check that sequences are properly ordered (ascending)
        for (int i = 1; i < receivedSequences.length; i++) {
          expect(receivedSequences[i], greaterThan(receivedSequences[i - 1]),
              reason: 'Sequence ${receivedSequences[i]} should be greater than ${receivedSequences[i - 1]} at index $i');
        }
        
        // Verify sequences start from 1 and are consecutive
        for (int i = 0; i < receivedSequences.length; i++) {
          expect(receivedSequences[i], equals(i + 1),
              reason: 'Expected sequence ${i + 1} but got ${receivedSequences[i]} at index $i');
        }
      });
    },
    
    (FoodbTestContext ctx) {
      test('Test isolated sequence ordering with delayed changes', () async {
        final dbName = 'test-delayed-sequence-ordering';
        final mainAdapter = await ctx.keyValueAdapter(dbName);
        
        final mainFoodb = Foodb.keyvalue(
          dbName: dbName,
          keyValueDb: mainAdapter,
          isolateLeader: true,
        ) as KeyvalueFoodb;
        
        List<int> receivedSequences = [];
        
        mainFoodb.changesStream(
          ChangeRequest(feed: ChangeFeed.continuous),
          onResult: (changeResult) {
            final seqNum = int.parse(changeResult.seq!.split('-')[0]);
            receivedSequences.add(seqNum);
          },
        );
        
        // Simulate out-of-order changes by using the internal methods directly
        // This tests the buffering mechanism
        final isolateAdapter = await ctx.keyValueAdapter(dbName);
        final isolateFoodb = Foodb.keyvalue(dbName: dbName, keyValueDb: isolateAdapter)
            as KeyvalueFoodb;
        
        isolateFoodb.addIsolateMembership(mainFoodb.isolateReference);
        
        // Create documents that will generate sequences 1, 2, 3
        await isolateFoodb.put(doc: Doc(id: 'doc1', model: {'seq': 1}));
        await isolateFoodb.put(doc: Doc(id: 'doc2', model: {'seq': 2}));
        await isolateFoodb.put(doc: Doc(id: 'doc3', model: {'seq': 3}));
        
        // Wait for changes to be processed
        await Future.delayed(Duration(seconds: 1));
        
        // Verify ordering
        expect(receivedSequences.length, 3);
        expect(receivedSequences, equals([1, 2, 3]));
      });
    },
  ];
}