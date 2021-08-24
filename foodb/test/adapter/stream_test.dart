import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StreamController<String> localController = StreamController.broadcast();
  test('stream', () {
    var sub = localController.stream.listen((event) {});
    StreamController<String> streamController = new StreamController();

    var fn = expectAsync1((result) {
      sub.cancel();
      streamController.close();
      expect(result, isNotNull);
    });

    var fn2 = expectAsync0(() {
      expect(1 + 1, 2);
    });
    sub.onData((event) {
      streamController.sink.add(event);
      fn(event);
    });

    streamController.stream.listen((event) {
      print(event);
    });

    localController.add("event");
    localController.add("event");

    Future.delayed(Duration(seconds: 2)).then((value) => fn2());
  });
}
