library foodb_isolate_lock;

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:synchronized/synchronized.dart';

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

/// A manager class for handling lock events in an isolate.
/// This class uses a `ReceivePort` to listen for lock messages.
/// This class should be run only in one isolate either in Main Isolate or it its dedicated isolate,
/// but never instantiated more than one across isolated.
///
/// The design for this lock as follows:
/// 1. When [FooDBIsolatedLock.synchronized] is called, it will send a [LockEvent.lock] together with it's [SendPort].
/// 2. The [SendPort] is added into [FooDBIsolateLockManager._lockedSendPorts].
/// 3. If the [FooDBIsolateLockManager._lockedSendPorts] is empty, it will send a [LockStatus.unlocked] to the [SendPort].
/// 4. The [ReceivePort] in [FooDBIsolatedLock.synchronized] listen for the [LockStatus.unlocked] message.
/// 5. Once it received the [LockStatus.unlocked], it will execute the computation.
/// 6. After the computation is done, it will send a [LockEvent.unlock] to the [FooDBIsolateLockManager] which will delete the [SendPort] from the [_lockedSendPorts].
/// 7. If there are more [SendPort] in the [FooDBIsolateLockManager._lockedSendPorts], it will send a [LockStatus.unlocked] to the next [SendPort] for next computation.
///
class FooDBIsolateLockManager {
  final ReceivePort _receivePort = ReceivePort();

  final List<SendPort> _lockedSendPorts = [];

  /// This is required to run for [_receivePort] to listen for messages.
  FooDBIsolateLockManager() {
    _init();
  }

  /// Close the [_receivePort] and remove the port name mapping.
  /// This is optional is the lock manager is intended to run the whole time the application is running.
  void close() {
    IsolateNameServer.removePortNameMapping(isolateName);
  }

  /// Initialize the [_receivePort] to listen for lock messages.
  /// This method is called in the constructor.
  ///
  /// How this works is when
  void _init() {
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
