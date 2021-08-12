import 'dart:math';

class Utils {
  static String randomString(int length) {
    const ch = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
    Random r = Random.secure();
    return String.fromCharCodes(
        Iterable.generate(length, (_) => ch.codeUnitAt(r.nextInt(ch.length))));
  }
}

class SequenceTool {
  SequenceTool(this._seq);

  String _seq;

  int get seqCount => int.parse(_seq.split('-')[0]);

  String get seqValue => _seq.split('-')[1];

  String increment() => '${seqCount + 1}-$seqValue';
}
