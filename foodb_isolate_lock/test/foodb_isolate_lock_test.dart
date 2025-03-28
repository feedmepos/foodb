import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb_isolate_lock/foodb_isolate_lock.dart';
import 'package:synchronized/synchronized.dart';

void isolatedComputation(Map input) {
  final sendPort = input['sendPort'] as SendPort;
  final receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);

  final foodbMock = FooDBMock(lock: FooDBIsolatedLock(), name: input['name']);

  if (input['triggerOnInit'] == true) {
    foodbMock.test(DateTime.now(), (a) {
      sendPort.send(a);
    });
  }

  receivePort.listen((message) {
    if (message == 'invoke') {
      foodbMock.test(DateTime.now(), (a) {
        sendPort.send(a);
      });
    }
  });
}

void main() async {
  testWidgets('test', (tester) async {
    await tester.runAsync(() async {
      FooDBIsolateLockManager();

      const numberOfEvents = 5;

      final wholeProcess = Completer();
      final allDatas = StreamController<String>();
      final List<String> emittedValues = [];
      allDatas.stream.listen((event) {
        emittedValues.add(event);
        if (emittedValues.length >= (numberOfEvents * 2)) {
          wholeProcess.complete();
        }
      });

      final port = ReceivePort();
      SendPort? sendPort;
      final completer = Completer();
      final port2 = ReceivePort();
      SendPort? sendPort2;
      final completer2 = Completer();
      final port3 = ReceivePort();
      final completer3 = Completer();
      SendPort? sendPort3;
      await Isolate.spawn(
          isolatedComputation, {'sendPort': port.sendPort, 'name': 'A'});
      port.listen((message) {
        if (message is SendPort) {
          sendPort = message;
          completer.complete();
        }
        if (message is String) {
          allDatas.sink.add(message);
        }
      });
      await Isolate.spawn(isolatedComputation,
          {'sendPort': port2.sendPort, 'name': 'B', 'triggerOnInit': true});
      port2.listen((message) {
        if (message is SendPort) {
          sendPort2 = message;
          completer2.complete();
        }
        if (message is String) {
          allDatas.sink.add(message);
        }
      });

      await Isolate.spawn(
          isolatedComputation, {'sendPort': port3.sendPort, 'name': 'C'});
      port3.listen((message) {
        if (message is SendPort) {
          sendPort3 = message;
          completer3.complete();
        }
        if (message is String) {
          allDatas.sink.add(message);
        }
      });

      await Future.forEach(
          [completer, completer2, completer3], (a) => a.future);
      sendPort?.send("invoke");
      sendPort2?.send("invoke");
      sendPort3?.send("invoke");
      sendPort2?.send("invoke");

      await wholeProcess.future;
      print(emittedValues);

      for (int i = 1; i < emittedValues.length; i++) {
        if (i % 2 == 0) continue;
        final prev = emittedValues[i - 1].replaceFirst(' START', '');
        final current = emittedValues[i].replaceFirst(' DONE', '');
        expect(prev, current);
      }
    });
  });
}

class FooDBMock {
  final Lock lock;
  final String name;

  FooDBMock({required this.lock, required this.name});

  Future<void> test([
    DateTime? time,
    Function(String)? onCallback,
  ]) async {
    await lock.synchronized(() async {
      onCallback?.call("$name $time START");
      await Future.delayed(const Duration(seconds: 2));
      onCallback?.call("$name $time DONE");
    });
  }
}
