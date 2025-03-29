import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_isolate_lock/foodb_isolate_lock.dart';
import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';

import 'foodb_objectbox_adapter_test.dart';

const dbName = 'put-get';
const prefix = 'test-';

void main() {
  testWidgets('test with lock', (tester) async {
    addTearDown(() async {
      var directory = join(Directory.current.path, 'temp/$dbName');
      final dir = Directory(directory);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });

    await tester.runAsync(() async {
      FooDBIsolateLockManager();
      final sendPorts = <SendPort>[];
      for (int i = 0; i < 10; i++) {
        final completer = Completer();
        final port = ReceivePort();
        SendPort? sendPort;
        await Isolate.spawn(isolatesDbInstance, {
          'sendPort': port.sendPort,
          'name': 'isolate $i',
        });
        port.listen((message) {
          if (message is SendPort) {
            sendPort = message;
            sendPorts.add(sendPort!);
            completer.complete();
          }
        });
        await completer.future;
      }

      for (final sendPort in sendPorts) {
        sendPort.send("invoke");
      }

      await Future.delayed(const Duration(seconds: 10));
    });
  });

  testWidgets('test with lock useObjectBoxLock', (tester) async {
    addTearDown(() async {
      var directory = join(Directory.current.path, 'temp/$dbName');
      final dir = Directory(directory);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });

    await tester.runAsync(() async {
      FooDBIsolateLockManager();
      final sendPorts = <SendPort>[];
      for (int i = 0; i < 10; i++) {
        final completer = Completer();
        final port = ReceivePort();
        SendPort? sendPort;
        await Isolate.spawn(isolatesDbInstance, {
          'sendPort': port.sendPort,
          'name': 'isolate $i',
          'useObjectBoxLock': true,
        });
        port.listen((message) {
          if (message is SendPort) {
            sendPort = message;
            sendPorts.add(sendPort!);
            completer.complete();
          }
        });
        await completer.future;
      }

      for (final sendPort in sendPorts) {
        sendPort.send("invoke");
      }

      await Future.delayed(const Duration(seconds: 10));
    });
  });
}

void isolatesDbInstance(Map input) async {
  final isolateName = input['name'] as String;
  Logger.root.onRecord.listen((message) {
    print('$isolateName:: $message');
  });
  final sendPort = input['sendPort'] as SendPort;
  final receivePort = ReceivePort();

  var name = '$prefix$dbName';
  var adapter = await getAdapterForIsolate(name);
  sendPort.send(receivePort.sendPort);
  adapter.store;

  Lock? lock;

  if (input['useObjectBoxLock'] == true) {
    lock = FooDBObjectBoxLock(store: adapter.store, isolateName: isolateName);
  } else {
    lock = FooDBIsolatedLock();
  }

  final db = Foodb.keyvalue(
    dbName: '$name',
    keyValueDb: adapter,
    autoCompaction: false,
    lock: lock,
  );

  void call() async {
    await db.put(doc: Doc(id: 'test-get', model: {}));

    var doc1 = await db.get(id: 'test-get', fromJsonT: (v) => {});

    await db.delete(id: doc1.id, rev: doc1.rev!);

    await db.get(id: doc1.id, rev: doc1.rev.toString(), fromJsonT: (v) => {});
  }

  if (input['triggerOnInit'] == true) {
    call();
  }

  receivePort.listen((message) async {
    if (message == 'invoke') {
      call();
    }
  });
}

class FooDBObjectBoxLock implements Lock {
  final Store store;

  final String? isolateName;

  FooDBObjectBoxLock({required this.store, this.isolateName});

  @override
  bool get inLock => throw UnimplementedError();

  @override
  bool get locked => throw UnimplementedError();

  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  }) async {
    await store.awaitQueueCompletion();

    var result = computation();
    if (result is Future) {
      final output = await result;
      return output;
    } else {
      return result;
    }
  }
}