import 'dart:async';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'helpers/race_condition_test_helpers.dart';

void main() {
  group('Integration test - Multiple isolate simulation', () {
    test('Simulated multiple isolate scenario should work correctly', () async {
      // Create two separate database instances to simulate multiple isolates
      final sourceCtx1 = InMemoryTestContext();
      final sourceCtx2 = InMemoryTestContext(); 
      final targetCtx = InMemoryTestContext();
      
      final sourceDB1 = await sourceCtx1.db('multi-isolate-source-1');
      final sourceDB2 = await sourceCtx2.db('multi-isolate-source-2'); 
      final targetDB = await targetCtx.db('multi-isolate-target');
      
      var totalReplicated = 0;
      var totalErrors = 0;
      final completer = Completer<void>();
      
      // Start replication from source1 to target
      final replication1 = replicate(
        sourceDB1,
        targetDB,
        continuous: true,
        debounce: Duration(milliseconds: 50),
        onError: (error, stackTrace) {
          print('Replication 1 error: $error');
          totalErrors++;
        },
        onCheckpoint: (checkpoint) async {
          totalReplicated += checkpoint.replicated.length;
          print('Replication 1 checkpoint: ${checkpoint.replicated.length} replicated, total: $totalReplicated');
          
          if (totalReplicated >= 15) { // 10 from DB1 + 5 from DB2
            completer.complete();
          }
        },
      );
      
      // Start replication from source2 to target  
      final replication2 = replicate(
        sourceDB2,
        targetDB,
        continuous: true,
        debounce: Duration(milliseconds: 50),
        onError: (error, stackTrace) {
          print('Replication 2 error: $error');
          totalErrors++;
        },
        onCheckpoint: (checkpoint) async {
          totalReplicated += checkpoint.replicated.length;
          print('Replication 2 checkpoint: ${checkpoint.replicated.length} replicated, total: $totalReplicated');
          
          if (totalReplicated >= 15) { // 10 from DB1 + 5 from DB2
            completer.complete();
          }
        },
      );
      
      // Give replications time to start
      await Future.delayed(Duration(milliseconds: 100));
      
      // Add documents to both sources concurrently to simulate the original issue
      final futures = <Future>[];
      
      // Add to source 1
      for (int i = 0; i < 10; i++) {
        futures.add(sourceDB1.put(doc: Doc(id: 'isolate1-doc-$i', model: {'source': 1, 'index': i})));
      }
      
      // Add to source 2 
      for (int i = 0; i < 5; i++) {
        futures.add(sourceDB2.put(doc: Doc(id: 'isolate2-doc-$i', model: {'source': 2, 'index': i})));
      }
      
      // Wait for all puts to complete
      await Future.wait(futures);
      
      // Wait for replication to complete
      await completer.future.timeout(Duration(seconds: 10));
      
      replication1.abort();
      replication2.abort();
      
      // Verify results
      expect(totalErrors, equals(0), reason: 'No replication errors should occur');
      expect(totalReplicated, equals(15), reason: 'All 15 documents should be replicated');
      
      // Verify all documents exist in target
      for (int i = 0; i < 10; i++) {
        final doc = await targetDB.get(id: 'isolate1-doc-$i', fromJsonT: (json) => json);
        expect(doc.model['source'], equals(1));
        expect(doc.model['index'], equals(i));
      }
      
      for (int i = 0; i < 5; i++) {
        final doc = await targetDB.get(id: 'isolate2-doc-$i', fromJsonT: (json) => json);
        expect(doc.model['source'], equals(2)); 
        expect(doc.model['index'], equals(i));
      }
      
      print('✅ Multiple isolate simulation successful: $totalReplicated documents replicated with 0 errors');
    });
  });
}