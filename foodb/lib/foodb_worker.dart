import 'dart:async';
import 'dart:isolate';

class _WorkerRequest {
  Function fn;
  dynamic arg;
  SendPort replyTo;
  _WorkerRequest({
    required this.fn,
    required this.arg,
    required this.replyTo,
  });
}

class FoodbWorker {
  static SendPort? _sendPort;
  static Isolate? isolate;
  static init() async {
    if (isolate == null) {
      var receivePort = ReceivePort();
      isolate = await Isolate.spawn(_foodbWorker, receivePort.sendPort);
      _sendPort = await receivePort.first;
      receivePort.close();
    }
  }

  static Future<T> execute<T, T2>(FutureOr<T> Function(T2) fn, T2 arg) async {
    if (_sendPort != null) {
      var receivePort = ReceivePort();
      _sendPort!.send(
          _WorkerRequest(fn: fn, arg: arg, replyTo: receivePort.sendPort));
      var res = await receivePort.first;
      receivePort.close();
      return res;
    }
    throw Exception('worker must be initialized before use');
  }
}

_foodbWorker(SendPort sendPort) async {
  var receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (_WorkerRequest req in receivePort) {
    var res = await req.fn(req.arg);
    req.replyTo.send(res);
  }
}
