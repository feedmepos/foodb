// Full idea from https://github.com/pouchdb/pouchdb/blob/master/packages/node_modules/pouchdb-collate/src/index.js

import 'dart:collection';

const MIN_MAGNITUDE = -324;
const MAGNITUDE_DIGITS = 3;

const RESERVED_DELIMITER = "\u0000";
const SEPERATOR = "";

String stripReservedCharacter(String str) {
  return str
      .replaceAll("\u0002", '\u0002\u0002')
      .replaceAll("\u0001", '\u0001\u0002')
      .replaceAll(RESERVED_DELIMITER, '\u0001\u0001');
}

String revertStripReservedCharacter(String str) {
  return str
      .replaceAll("\u0001\u0001", RESERVED_DELIMITER)
      .replaceAll("\u0001\u0002", '\u0001')
      .replaceAll("\u0002\u0002", '\u0002');
}

abstract class _Encoder<T> {
  get COLLATION_TYPE_STR;
  String encode(T val);
  T decode(dynamic val);
}

class _NullEncoder extends _Encoder {
  static const String COLLATION_TYPE = '0';
  get COLLATION_TYPE_STR => _NullEncoder.COLLATION_TYPE;
  String encode(val) {
    return "";
  }

  decode(val) {
    return null;
  }
}

class _BoolEncoder extends _Encoder<bool> {
  static const String COLLATION_TYPE = '1';
  get COLLATION_TYPE_STR => _BoolEncoder.COLLATION_TYPE;
  String encode(val) {
    return val ? "1" : "0";
  }

  decode(str) {
    str as String;
    return str == '1';
  }
}

class _NumEncoder extends _Encoder<num> {
  static const String COLLATION_TYPE = '2';
  get COLLATION_TYPE_STR => _NumEncoder.COLLATION_TYPE;
  /**
   * syntax: <sign><magnitude><factor>
   */
  String encode(val) {
    String result = "";
    if (val == 0) {
      result = '1';
    } else {
      final isNegative = val < 0;
      result = isNegative ? '0' : '2';

      final expFormat = val.toStringAsExponential().split('e+');
      final magnitude = int.parse(expFormat[1]);

      final magForComparison =
          ((isNegative ? -magnitude : magnitude) - MIN_MAGNITUDE);
      final magString =
          magForComparison.toString().padLeft(MAGNITUDE_DIGITS, '0');

      result += SEPERATOR + magString;

      var factor = double.parse(expFormat[0]).abs();
      if (isNegative) factor = 10 - factor;
      var factorStr =
          factor.toStringAsFixed(20).replaceAll(RegExp(r'\.?0+$'), "");
      result += SEPERATOR + factorStr;
    }

    return result;
  }

  decode(str) {
    str as String;
    if (str[0] == '1') return 0;
    final isNegative = str[0] == '0';
    final magnitudeStr = str.substring(1, MAGNITUDE_DIGITS + 1);
    var magnitue = int.parse(magnitudeStr) + MIN_MAGNITUDE;
    final factorStr = str.substring(1 + MAGNITUDE_DIGITS);
    var factor = num.parse(factorStr);
    if (isNegative) {
      magnitue = -magnitue;
      factor = factor - 10;
    }

    if (magnitue == 0) return factor;
    return double.parse('${factor}e${magnitue}');
  }
}

class _StrEncoder extends _Encoder<String> {
  static const String COLLATION_TYPE = '3';
  get COLLATION_TYPE_STR => _StrEncoder.COLLATION_TYPE;
  String encode(val) {
    return stripReservedCharacter(val);
  }

  decode(str) {
    return revertStripReservedCharacter(str);
  }
}

class _ArrEncoder extends _Encoder<List> {
  static const String COLLATION_TYPE = '4';
  get COLLATION_TYPE_STR => _ArrEncoder.COLLATION_TYPE;
  String encode(val) {
    return val.map((e) => encodeToIndex(e)).join();
  }

  decode(val) {
    return val;
  }
}

class _ObjEncoder extends _Encoder<Map> {
  static const String COLLATION_TYPE = '5';
  get COLLATION_TYPE_STR => _ObjEncoder.COLLATION_TYPE;
  String encode(val) {
    String result = '';
    val.forEach((key, value) {
      result += encodeToIndex(key) + encodeToIndex(value);
    });
    return result;
  }

  decode(val) {
    final result = Map<String, dynamic>();
    for (var i = 0; i < val.length; i += 2) {
      result[val[i]] = val[i + 1];
    }
    return result;
  }
}

normalizeKey(dynamic key) {
  if (key is num && (key.isNaN || key.isInfinite)) {
    return null;
  }
  if (key is DateTime) {
    return key.toIso8601String();
  }
  if (key is List) {
    return key.map((e) => normalizeKey(key));
  }
  if (key is Map) {
    return key
        .map((key, value) => MapEntry(normalizeKey(key), normalizeKey(value)));
  }
  return key;
}

final _nullEncoder = _NullEncoder();
final _boolEncoder = _BoolEncoder();
final _numEncoder = _NumEncoder();
final _strEncoder = _StrEncoder();
final _arrEncoder = _ArrEncoder();
final _objEncoder = _ObjEncoder();

_Encoder _getEncoderByRuntimeType(dynamic key) {
  if (key == null) return _nullEncoder;
  if (key is bool) return _boolEncoder;
  if (key is num) return _numEncoder;
  if (key is String) return _strEncoder;
  if (key is List) return _arrEncoder;
  if (key is Map) return _objEncoder;
  throw Exception('unsupported native type for encoding');
}

_Encoder _getEncoderByCollationType(String key) {
  switch (key) {
    case _NullEncoder.COLLATION_TYPE:
      return _nullEncoder;
    case _BoolEncoder.COLLATION_TYPE:
      return _boolEncoder;
    case _NumEncoder.COLLATION_TYPE:
      return _numEncoder;
    case _StrEncoder.COLLATION_TYPE:
      return _strEncoder;
    case _ArrEncoder.COLLATION_TYPE:
      return _arrEncoder;
    case _ObjEncoder.COLLATION_TYPE:
      return _objEncoder;
  }
  throw Exception('unsupported native type for encoding');
}

String encodeToIndex(dynamic key) {
  final encoder = _getEncoderByRuntimeType(key);
  return '${encoder.COLLATION_TYPE_STR}${encoder.encode(key)}$RESERVED_DELIMITER';
}

dynamic decodeFromIndex(String str) {
  StringBuffer buffer = StringBuffer();
  _Encoder? encoder;
  Queue<List<dynamic>> valueStack = Queue();
  Queue<_Encoder> collectionStack = Queue();

  for (final c in str.split("")) {
    // no encoder, mean a fresh start
    if (encoder == null) {
      // encounter delimiter means end collection
      // else build the new encoder
      if (c == RESERVED_DELIMITER) {
        final group = collectionStack.removeLast();
        final values = valueStack.removeLast();
        final result = group.decode(values);
        // if the root is collection type, return as result
        // else add it the parent collection value
        if (collectionStack.isEmpty) {
          return result;
        } else {
          valueStack.last.add(result);
        }
        continue;
      }
      encoder = _getEncoderByCollationType(c);
      // if the encoder is collection type, add to stack and start collection
      if (encoder is _ArrEncoder || encoder is _ObjEncoder) {
        valueStack.add([]);
        collectionStack.addLast(encoder);
        buffer = StringBuffer();
        encoder = null;
      }
      continue;
    }

    // reached the end of string, time to run encoder
    if (c == RESERVED_DELIMITER) {
      final value = encoder.decode(buffer.toString());

      // if the value is for the collection, add to stack
      // else return
      if (collectionStack.isNotEmpty) {
        valueStack.last.add(value);
      } else {
        return value;
      }
      buffer = StringBuffer();
      encoder = null;
      continue;
    }
    buffer.write(c);
  }
}
