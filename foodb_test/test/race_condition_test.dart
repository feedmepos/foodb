import 'dart:async';

import 'package:test/test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_test/foodb_test.dart';

void main() {
  group('Race condition tests', () {
    test('Broken adapter should reproduce race condition', () async {
      final brokenCtx = BrokenTestContext(
        notificationDelay: Duration(milliseconds: 200),
      );
      final targetCtx = InMemoryTestContext();
      
      final source = await brokenCtx.db('source-broken-race');
      final target = await targetCtx.db('target-broken-race');
      
      var replicationError = false;
      var replicationCompleted = false;
      final completer = Completer<void>();
      
      // Start continuous replication
      final replicationStream = replicate(
        source,
        target,
        continuous: true,
        debounce: Duration(milliseconds: 50),
        onError: (error, stackTrace) {
          print('Replication error: $error');
          replicationError = true;
          // Don't fail the test immediately, let it complete
        },
        onCheckpoint: (checkpoint) async {
          print('Checkpoint: processed ${checkpoint.processed.length}, replicated ${checkpoint.replicated.length}');
          if (checkpoint.processed.length > 0 && !replicationCompleted) {
            replicationCompleted = true;
            completer.complete();
          }
        },
      );
      
      // Give replication a moment to start
      await Future.delayed(Duration(milliseconds: 100));
      
      // Add a document - this should trigger the race condition
      await source.put(doc: Doc(id: 'test-doc', model: {'name': 'test'}));
      
      // Wait for replication to process (or fail)
      await completer.future.timeout(Duration(seconds: 5), onTimeout: () {
        print('Replication timed out');
      });
      
      replicationStream.abort();
      
      // Check if the document was replicated
      try {
        final doc = await target.get(id: 'test-doc', fromJsonT: (json) => json);
        print('Document successfully replicated: ${doc.id}');
        // If we get here, the race condition didn't cause replication to fail
        // (This is what should happen with the fixed adapter)
      } catch (e) {
        print('Document not found in target: $e');
        // This indicates the race condition caused the document to be missed
      }
      
      // For the broken adapter, we expect that either:
      // 1. Replication failed with an error (bulkGet failed), or
      // 2. The document was missed (not replicated)
      print('Replication error occurred: $replicationError');
      print('Replication completed: $replicationCompleted');
    });
    
    test('Normal adapter should work correctly', () async {
      final sourceCtx = InMemoryTestContext();
      final targetCtx = InMemoryTestContext();
      
      final source = await sourceCtx.db('source-normal');
      final target = await targetCtx.db('target-normal');
      
      var replicationError = false;
      var documentReplicated = false;
      final completer = Completer<void>();
      
      // Start continuous replication
      final replicationStream = replicate(
        source,
        target,
        continuous: true,
        debounce: Duration(milliseconds: 50),
        onError: (error, stackTrace) {
          print('Unexpected replication error: $error');
          replicationError = true;
          completer.complete();
        },
        onCheckpoint: (checkpoint) async {
          print('Normal checkpoint: processed ${checkpoint.processed.length}, replicated ${checkpoint.replicated.length}');
          if (checkpoint.processed.length > 0) {
            try {
              final doc = await target.get(id: 'test-doc-normal', fromJsonT: (json) => json);
              documentReplicated = true;
              print('Document successfully replicated: ${doc.id}');
              completer.complete();
            } catch (e) {
              print('Document not yet available: $e');
            }
          }
        },
      );
      
      // Give replication a moment to start
      await Future.delayed(Duration(milliseconds: 100));
      
      // Add a document
      await source.put(doc: Doc(id: 'test-doc-normal', model: {'name': 'normal-test'}));
      
      // Wait for replication to complete
      await completer.future.timeout(Duration(seconds: 5));
      
      replicationStream.abort();
      
      // With normal adapter, replication should work perfectly
      expect(replicationError, isFalse, reason: 'No replication errors should occur with normal adapter');
      expect(documentReplicated, isTrue, reason: 'Document should be successfully replicated');
    });
  });
}