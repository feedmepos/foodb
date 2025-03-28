import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
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
      final port = ReceivePort();
      SendPort? sendPort;
      final completer = Completer();
      final port2 = ReceivePort();
      SendPort? sendPort2;
      final completer2 = Completer();
      await Isolate.spawn(isolatesDbInstance, {
        'sendPort': port.sendPort,
        'name': 'A',
      });
      port.listen((message) {
        if (message is SendPort) {
          sendPort = message;
          completer.complete();
        }
      });

      await completer.future;

      await Isolate.spawn(isolatesDbInstance, {
        'sendPort': port2.sendPort,
        'name': 'B',
        'triggerOnInit': true,
      });
      port2.listen((message) {
        if (message is SendPort) {
          sendPort2 = message;
          completer2.complete();
        }
      });

      await completer2.future;

      sendPort?.send("invoke");
      sendPort2?.send("invoke");

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
      final port = ReceivePort();
      SendPort? sendPort;
      final completer = Completer();
      final port2 = ReceivePort();
      SendPort? sendPort2;
      final completer2 = Completer();
      await Isolate.spawn(isolatesDbInstance, {
        'sendPort': port.sendPort,
        'name': 'A',
        'useObjectBoxLock': true,
      });
      port.listen((message) {
        if (message is SendPort) {
          sendPort = message;
          completer.complete();
        }
      });

      await completer.future;

      await Isolate.spawn(isolatesDbInstance, {
        'sendPort': port2.sendPort,
        'name': 'B',
        'triggerOnInit': true,
        'useObjectBoxLock': true,
      });
      port2.listen((message) {
        if (message is SendPort) {
          sendPort2 = message;
          completer2.complete();
        }
      });

      await completer2.future;

      sendPort?.send("invoke");
      sendPort2?.send("invoke");

      await Future.delayed(const Duration(seconds: 10));
    });
  });
}

void isolatesDbInstance(Map input) async {
  final sendPort = input['sendPort'] as SendPort;
  final isolateName = input['name'] as String;
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
    print('$isolateName put');
    var putResponse = await db.put(doc: Doc(id: 'test-get', model: {}));
    print('$isolateName put ${putResponse.ok}');

    var doc1 = await db.get(id: 'test-get', fromJsonT: (v) => {});

    print('$isolateName delete');
    final deleteResponse = await db.delete(id: doc1.id, rev: doc1.rev!);
    print('$isolateName delete ${deleteResponse.ok}');

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

const isolateName = 'package:foodb_isolate_lock';

enum LockEvent { lock, unlock }

enum LockStatus { locked, unlocked }

class LockMessage {
  final LockEvent type;
  final SendPort port;

  LockMessage({required this.type, required this.port});
}

class LockStatusMessage {
  final LockStatus type;

  LockStatusMessage({required this.type});
}

class FooDBIsolateLockManager {
  final ReceivePort _receivePort = ReceivePort();

  final List<SendPort> _lockedSendPorts = [];

  FooDBIsolateLockManager() {
    init();
  }

  void close() {
    IsolateNameServer.removePortNameMapping(isolateName);
  }

  void init() {
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, isolateName);
    _receivePort.listen((message) {
      if (message is! LockMessage) return;
      final type = message.type;
      final replyPort = message.port;

      if (type == LockEvent.lock) {
        if (_lockedSendPorts.isEmpty) {
          replyPort.send(LockStatusMessage(type: LockStatus.unlocked));
        } else {
          replyPort.send(LockStatusMessage(type: LockStatus.locked));
        }
        _lockedSendPorts.add(replyPort);
      }

      if (type == LockEvent.unlock) {
        if (_lockedSendPorts.isEmpty) {
          replyPort.send(LockStatusMessage(type: LockStatus.unlocked));
        } else {
          _lockedSendPorts
              .removeAt(0)
              .send(LockStatusMessage(type: LockStatus.unlocked));

          if (_lockedSendPorts.isNotEmpty) {
            _lockedSendPorts.first
                .send(LockStatusMessage(type: LockStatus.unlocked));
          }
        }
      }
    });
  }
}

class FooDBIsolatedLock implements Lock {
  final List<ReceivePort> receivePorts = [];

  FooDBIsolatedLock();

  @override
  bool get inLock => throw UnimplementedError();

  @override
  bool get locked => throw UnimplementedError();

  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  }) async {
    final completer = Completer();
    final receivePort = ReceivePort();
    receivePorts.add(receivePort);

    receivePort.listen((message) {
      if (message is! LockStatusMessage) return;
      if (message.type == LockStatus.unlocked) {
        if (!completer.isCompleted) completer.complete();
      }
    });

    IsolateNameServer.lookupPortByName(isolateName)?.send(LockMessage(
      type: LockEvent.lock,
      port: receivePort.sendPort,
    ));

    await completer.future;

    var result = computation();
    if (result is Future) {
      final output = await result;
      IsolateNameServer.lookupPortByName(isolateName)?.send(LockMessage(
        type: LockEvent.unlock,
        port: receivePort.sendPort,
      ));
      receivePorts.remove(receivePort);
      return output;
    } else {
      IsolateNameServer.lookupPortByName(isolateName)?.send(LockMessage(
        type: LockEvent.unlock,
        port: receivePort.sendPort,
      ));
      receivePorts.remove(receivePort);
      return result;
    }
  }
}
