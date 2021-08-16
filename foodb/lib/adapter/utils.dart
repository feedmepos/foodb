import 'dart:math';

class Utils {
  static String randomString(int length) {
    const ch = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
    Random r = Random.secure();
    return String.fromCharCodes(
        Iterable.generate(length, (_) => ch.codeUnitAt(r.nextInt(ch.length))));
  }

  static generateSequence(int current) {
    return '$current-${Utils.randomString(30)}';
  }
}

abstract class Incrementer {
  Incrementer(this.value);

  String value;

  int get index => int.parse(value.split('-')[0]);

  String get content => value.split('-')[1];

  String increment() => '${index + 1}-$content';
}

class SequenceTool extends Incrementer {
  SequenceTool(String value) : super(value);

  static String generate() => '1-${Utils.randomString(100)}';
}

class RevisionTool extends Incrementer {
  RevisionTool(String revision) : super(revision);

  static String generate() => '1-${Utils.randomString(20)}';
}
