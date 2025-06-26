import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  group('Race condition fix verification', () {
    test('Fixed adapter should handle rapid replication correctly', () async {
      final sourceCtx = InMemoryTestContext();
      final targetCtx = InMemoryTestContext();
      
      final source = await sourceCtx.db('source-race-fix-test');
      final target = await targetCtx.db('target-race-fix-test');
      
      var documentsProcessed = 0;
      var documentsReplicated = 0;
      var replicationErrors = 0;
      final completer = Completer<void>();
      
      // Start continuous replication with short debounce to catch race conditions
      final replicationStream = replicate(
        source,
        target,
        continuous: true,
        debounce: Duration(milliseconds: 10), // Very short debounce to stress test
        maxBatchSize: 1, // Process one at a time to maximize race condition chances
        onError: (error, stackTrace) {
          print('Replication error: $error');
          replicationErrors++;
        },
        onCheckpoint: (checkpoint) async {
          documentsProcessed += checkpoint.processed.length;
          documentsReplicated += checkpoint.replicated.length;
          
          print('Checkpoint: processed=$documentsProcessed, replicated=$documentsReplicated, errors=$replicationErrors');
          
          // Complete test when we've processed all 10 documents
          if (documentsProcessed >= 10) {
            completer.complete();
          }
        },
      );
      
      // Give replication a moment to start
      await Future.delayed(Duration(milliseconds: 50));
      
      // Add multiple documents in rapid succession to stress test the race condition fix
      for (int i = 0; i < 10; i++) {
        await source.put(doc: Doc(id: 'rapid-$i', model: {'index': i, 'data': 'test-$i'}));
        // Small delay to allow change notifications to propagate
        await Future.delayed(Duration(milliseconds: 5));
      }
      
      // Wait for replication to complete
      await completer.future.timeout(Duration(seconds: 10));
      
      replicationStream.abort();
      
      // Verify all documents were successfully replicated
      expect(replicationErrors, equals(0), reason: 'No replication errors should occur with race condition fix');
      expect(documentsReplicated, equals(10), reason: 'All 10 documents should be successfully replicated');
      
      // Verify documents exist in target
      for (int i = 0; i < 10; i++) {
        final doc = await target.get(id: 'rapid-$i', fromJsonT: (json) => json);
        expect(doc.model['index'], equals(i));
        expect(doc.model['data'], equals('test-$i'));
      }
      
      print('✅ Race condition fix verified: $documentsReplicated/$documentsProcessed documents replicated successfully with 0 errors');
    });
    
    test('Multiple concurrent operations should not cause race conditions', () async {
      final sourceCtx = InMemoryTestContext();
      final targetCtx = InMemoryTestContext();
      
      final source = await sourceCtx.db('source-concurrent-race-fix');
      final target = await targetCtx.db('target-concurrent-race-fix');
      
      var totalProcessed = 0;
      var totalReplicated = 0;
      var totalErrors = 0;
      final completer = Completer<void>();
      
      // Start continuous replication
      final replicationStream = replicate(
        source,
        target,
        continuous: true,
        debounce: Duration(milliseconds: 20),
        onError: (error, stackTrace) {
          print('Concurrent replication error: $error');
          totalErrors++;
        },
        onCheckpoint: (checkpoint) async {
          totalProcessed += checkpoint.processed.length;
          totalReplicated += checkpoint.replicated.length;
          
          print('Concurrent checkpoint: processed=$totalProcessed, replicated=$totalReplicated, errors=$totalErrors');
          
          // Complete when we've processed all 20 documents (10 + 10)
          if (totalProcessed >= 20) {
            completer.complete();
          }
        },
      );
      
      // Give replication a moment to start
      await Future.delayed(Duration(milliseconds: 50));
      
      // Simulate concurrent operations from different sources
      final futures = <Future>[];
      
      // Batch 1: Add 10 documents concurrently
      for (int i = 0; i < 10; i++) {
        futures.add(source.put(doc: Doc(id: 'concurrent-1-$i', model: {'batch': 1, 'index': i})));
      }
      
      // Batch 2: Add another 10 documents concurrently after a small delay
      await Future.delayed(Duration(milliseconds: 10));
      for (int i = 0; i < 10; i++) {
        futures.add(source.put(doc: Doc(id: 'concurrent-2-$i', model: {'batch': 2, 'index': i})));
      }
      
      // Wait for all puts to complete
      await Future.wait(futures);
      
      // Wait for replication to complete
      await completer.future.timeout(Duration(seconds: 15));
      
      replicationStream.abort();
      
      // Verify results
      expect(totalErrors, equals(0), reason: 'No replication errors should occur with concurrent operations');
      expect(totalReplicated, equals(20), reason: 'All 20 concurrent documents should be replicated');
      
      // Verify all documents exist in target
      for (int batch = 1; batch <= 2; batch++) {
        for (int i = 0; i < 10; i++) {
          final doc = await target.get(id: 'concurrent-$batch-$i', fromJsonT: (json) => json);
          expect(doc.model['batch'], equals(batch));
          expect(doc.model['index'], equals(i));
        }
      }
      
      print('✅ Concurrent operations race condition fix verified: $totalReplicated documents replicated successfully');
    });
  });
}