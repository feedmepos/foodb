import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

RevFromJsonString(String? str) {
  if (str == null) {
    return null;
  }
  var splitted = str.split('-');
  return Rev(index: int.parse(splitted[0]), md5: splitted[1]);
}

RevToJsonString(Rev? instance) {
  if (instance == null) {
    return null;
  }
  return '${instance.index}-${instance.md5}';
}

class Rev {
  int index;
  String md5;
  Rev({
    required this.index,
    required this.md5,
  });

  Rev increase(Map<String, dynamic> json) {
    return Rev(
        index: index + 1,
        md5: crypto.md5.convert(utf8.encode(jsonEncode(json))).toString());
  }

  @override
  String toString() {
    return RevToJsonString(this);
  }

  factory Rev.fromString(String str) {
    return RevFromJsonString(str);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rev && other.index == index && other.md5 == md5;
  }

  @override
  int get hashCode => index.hashCode ^ md5.hashCode;

  int compareTo(Rev other) {
    return this.toString().compareTo(other.toString());
  }
}
