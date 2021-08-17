import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/methods/changes.dart';

void main() {
  StreamController<String> streamController =
      StreamController<String>.broadcast();
  test('stream', () {
    var fn = expectAsync1((ChangeResponse result) {
      print(result.lastSeq);
      expect(result, isNotNull);
    });

    streamController.onListen = () {
      streamController.sink.add('\"last_seq\":\"0\", \"pending\": 0}');
    };

    ChangesStream changesStream = ChangesStream(
        stream: streamController.stream, feed: ChangeFeed.continuous);
    changesStream.onResult((result) => print(result));
    changesStream.onComplete((result) => fn(result));
    //streamController.add("\"last_seq\":\"0\", \"pending\": 0}");
  });
}
