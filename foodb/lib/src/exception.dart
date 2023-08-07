import 'dart:convert';
import 'package:http/http.dart';

class AdapterException implements Exception {
  String error;
  String? reason;
  int? code;
  AdapterException({required this.error, this.reason, this.code});

  @override
  String toString() => 'AdapterException(error: $error, reason: $reason)';

  static fromResponse(Response response) {
    final jsonString = utf8.decode(response.bodyBytes);
    final json = jsonDecode(jsonString);
    return AdapterException(
      error: json['error'],
      reason: json['reason'],
      code: response.statusCode,
    );
  }
}
