import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class Rev {
  int index;
  String md5;
  Rev({
    required this.index,
    required this.md5,
  });

  factory Rev.parse(String str) {
    var splitted = str.split('-');
    return Rev(index: int.parse(splitted[0]), md5: splitted[1]);
  }

  Rev increase(Map<String, dynamic> json) {
    return Rev(
        index: index + 1,
        md5: crypto.md5.convert(utf8.encode(jsonEncode(json))).toString());
  }

  @override
  String toString() {
    return '$index-$md5';
  }
}
