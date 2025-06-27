import 'dart:async';
import 'dart:isolate';

import 'package:flat_buffers/flex_buffers.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_test/foodb_test.dart';
import 'package:test/test.dart';

import 'key_value_broken.dart';
import '../../foodb_objectbox_adapter_test.dart';

class IsolateMessage {
  final String type;
  final dynamic data;
  final SendPort? replyTo;

  IsolateMessage({
    required this.type,
    this.data,
    this.replyTo,
  });
}

void isolateWorker(SendPort mainSendPort) async {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  // Helper function to send log messages to main isolate
  void log(String message) {
    mainSendPort.send({
      'type': 'log',
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  KeyvalueFoodbBrokenRaceCondition? brokenFoodb;

  await for (final message in receivePort) {
    if (message is IsolateMessage) {
      try {
        switch (message.type) {
          case 'init':
            final dbName = message.data['dbName'] as String;
            final reference =
                message.data['reference'] as KeyvalueFoodbIsolateRef;
            log('Initializing broken FooDB with dbName: $dbName');
            brokenFoodb = KeyvalueFoodbBrokenRaceCondition(
              dbName: dbName,
              keyValueDb: await getAdapter(dbName,
                  factory: (store) => SlowObjectBoxAdapter(store)),
              autoCompaction: false,
            );
            await brokenFoodb.initDb();
            log('FooDB initialized successfully');
            brokenFoodb.addIsolateMembership(reference);
            log('Added isolate membership');

            // Send our receive port to the main isolate so it can register us with the leader
            message.replyTo?.send({
              'success': true,
            });
            break;

          case 'put':
            if (brokenFoodb != null) {
              final docData = message.data;
              log('Putting document: ${docData['id']}');
              final doc = Doc<Map<String, dynamic>>(
                id: docData['id'],
                model: Map<String, dynamic>.from(docData['model']),
              );
              final response = await brokenFoodb.put(doc: doc);
              log('Put document in broken isolate: ${docData['id']} - Success: ${response.ok}');
              message.replyTo?.send({
                'success': true,
                'response': {
                  'ok': response.ok,
                  'id': response.id,
                  'rev': response.rev.toString(),
                }
              });
            } else {
              log('Error: FooDB not initialized for put operation');
              message.replyTo
                  ?.send({'success': false, 'error': 'FooDB not initialized'});
            }
            break;

          case 'get':
            if (brokenFoodb != null) {
              final docId = message.data['id'] as String;
              log('Getting document: $docId');
              try {
                final doc = await brokenFoodb.get(
                  id: docId,
                  fromJsonT: (json) => json,
                );
                log('Retrieved document: $docId');
                message.replyTo?.send({
                  'success': true,
                  'doc': {
                    'id': doc.id,
                    'rev': doc.rev?.toString(),
                    'model': doc.model,
                  }
                });
              } catch (e) {
                log('Error getting document $docId: $e');
                message.replyTo
                    ?.send({'success': false, 'error': e.toString()});
              }
            } else {
              log('Error: FooDB not initialized for get operation');
              message.replyTo
                  ?.send({'success': false, 'error': 'FooDB not initialized'});
            }
            break;

          case 'destroy':
            if (brokenFoodb != null) {
              log('Destroying FooDB');
              await brokenFoodb.destroy();
              brokenFoodb = null;
            }
            message.replyTo?.send({'success': true});
            break;
        }
      } catch (e) {
        log('Error in isolate worker: $e');
        message.replyTo?.send({'success': false, 'error': e.toString()});
      }
    }
  }
}

class IsolateController {
  late Isolate isolate;
  late SendPort isolateSendPort;
  final ReceivePort receivePort = ReceivePort();
  final Function(String, DateTime) logger;

  IsolateController(this.logger);

  Future<void> init() async {
    Completer<void> spawned = Completer<void>();

    // Listen for log messages from the isolate
    receivePort.listen((message) {
      if (message is Map && message['type'] == 'log') {
        logger(
          message['message'],
          DateTime.parse(message['timestamp']),
        );
      } else if (message is SendPort) {
        isolateSendPort = message;
        spawned.complete();
      }
    });

    isolate = await Isolate.spawn(isolateWorker, receivePort.sendPort);

    await spawned.future;
  }

  Future<Map<String, dynamic>> sendMessage(String type, {dynamic data}) async {
    final completer = Completer<Map<String, dynamic>>();
    final replyPort = ReceivePort();

    replyPort.listen((response) {
      completer.complete(Map<String, dynamic>.from(response));
      replyPort.close();
    });

    isolateSendPort.send(IsolateMessage(
      type: type,
      data: data,
      replyTo: replyPort.sendPort,
    ));

    return completer.future;
  }

  void dispose() {
    receivePort.close();
    isolate.kill();
  }
}

void main() {
  group('Race Condition Reproduction Tests', () {
    test('reproduce race condition with isolate and replication', () async {
      final dbName =
          'race-condition-source-${(DateTime.now().millisecondsSinceEpoch / 1000).ceil()}';
      // Create lead isolate FooDB as source (main isolate)
      final sourceFoodb = Foodb.keyvalue(
        dbName: dbName,
        keyValueDb: await getAdapter(dbName),
        autoCompaction: false,
        isolateLeader: true,
      ) as KeyvalueFoodb;
      await sourceFoodb.initDb();

      log(String message, {DateTime? timestamp}) {
        if (timestamp == null) {
          timestamp = DateTime.now();
        }
        print('[1: ${timestamp.toIso8601String()}] $message');
      }

      // Setup isolate controller
      final isolateController =
          IsolateController((String message, DateTime timestamp) {
        print('[2: ${timestamp.toIso8601String()}] $message');
      });
      await isolateController.init();

      // Initialize broken FooDB in isolate with the leader's isolate reference
      final initResponse = await isolateController.sendMessage('init', data: {
        'dbName': dbName,
        'reference': sourceFoodb.isolateReference,
      });
      expect(initResponse['success'], isTrue);

      // Create target FooDB for replication
      final targetFoodb = Foodb.keyvalue(
        dbName: 'race-condition-target',
        keyValueDb: KeyValueAdapter.inMemory(),
        autoCompaction: false,
      );
      await targetFoodb.initDb();

      // Set up replication
      final replicationCompleter = Completer<void>();
      var replicationCheckpointCount = 0;

      final replicationStream = replicate(
        sourceFoodb,
        targetFoodb,
        continuous: true,
        maxBatchSize: 1,
        debounce: Duration(milliseconds: 1),
        onResult: (r) {
          log('received change reuslt: ${r.id}');
        },
        onCheckpoint: (checkpoint) async {
          replicationCheckpointCount++;
          log('Replication checkpoint $replicationCheckpointCount: processed ${checkpoint.processed.length} docs');

          // Check if we've processed enough checkpoints to consider replication active
          if (replicationCheckpointCount >= 2) {
            if (!replicationCompleter.isCompleted) {
              replicationCompleter.complete();
            }
          }
        },
        onError: (error, stackTrace) {
          log('Replication error: $error');
          if (!replicationCompleter.isCompleted) {
            replicationCompleter
                .completeError(error ?? Exception('Unknown replication error'));
          }
        },
      );

      try {
        // Put a document from the broken key-value in the isolate
        final putResponse = await isolateController.sendMessage('put', data: {
          'id': 'test-race-doc-1',
          'model': {
            'data': 'test data from broken isolate',
            'timestamp': DateTime.now().toIso8601String(),
          }
        });

        expect(putResponse['success'], isTrue);

        // Put another document directly in source FooDB to trigger second replication
        Future.delayed(Duration(seconds: 1));
        await sourceFoodb.put(
            doc: Doc(
                id: 'trigger-doc', model: {'purpose': 'trigger replication'}));

        // Wait for some replication activity
        await Future.any([
          replicationCompleter.future,
          Future.delayed(Duration(seconds: 1))
        ]);

        // Allow some time for replication to process
        await Future.delayed(Duration(seconds: 2));

        // Check if documents exist in target FooDB
        log('Checking target FooDB for replicated documents...');

        try {
          final triggerDoc = await targetFoodb.get(
            id: 'trigger-doc',
            fromJsonT: (json) => json,
          );
          log('Trigger doc found in target: ${triggerDoc.id}');
        } catch (e) {
          log('Trigger doc not found in target: $e');
        }

        // The critical test: check if the document from broken isolate replicated
        try {
          final replicatedDoc = await targetFoodb.get(
            id: 'test-race-doc-1',
            fromJsonT: (json) => json,
          );
          log('SUCCESS: Document from broken isolate was replicated to target');

          // This would indicate the race condition is NOT occurring
          expect(replicatedDoc.id, equals('test-race-doc-1'));
        } catch (e) {
          log('RACE CONDITION DETECTED: Document from broken isolate was NOT replicated to target');
          log('Error: $e');

          // This would indicate the race condition IS occurring
          expect(e, isA<AdapterException>());
          expect(
              e.toString().contains('missing') ||
                  e.toString().contains('not_found'),
              isTrue);
        }

        // Verify the document exists in the source using the isolate
        final getResponse = await isolateController
            .sendMessage('get', data: {'id': 'test-race-doc-1'});

        if (getResponse['success']) {
          log('Document exists in broken isolate source');
        } else {
          log('Document not found in broken isolate source: ${getResponse['error']}');
        }

        // Show all documents in target for debugging
        final allDocs =
            await targetFoodb.allDocs(GetViewRequest(), (json) => json);
        log('All documents in target FooDB:');
        for (final row in allDocs.rows) {
          log('  - ${row.id} (rev: ${row.value})');
        }
      } finally {
        // Cleanup
        replicationStream.abort();
        await isolateController.sendMessage('destroy');
        isolateController.dispose();
        await sourceFoodb.destroy();
        await targetFoodb.destroy();
      }
    }, timeout: Timeout(Duration(seconds: 30)));
  });
}
