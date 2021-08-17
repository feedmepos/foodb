import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  StreamController<String> streamController =
      StreamController<String>.broadcast();
  test('stream', () {
    streamController.stream.listen((event) {
      print(event);
    });
    streamController.sink.add("\"last_seq\":\"0\", \"pending\": 0}");
  });
}
