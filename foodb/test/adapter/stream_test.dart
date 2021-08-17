import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/methods/changes.dart';

void main() {
  StreamController<String> streamController =
      StreamController<String>.broadcast();
  test('stream', () {
    var fn = expectAsync1((result) {
      print(result);
      expect(result, isNotNull);
    });

    streamController.onListen = () {
      streamController.sink.add('event');
    };
    streamController.stream.listen((event) {
      fn(event);
    });
    //streamController.add("\"last_seq\":\"0\", \"pending\": 0}");
  });
}
