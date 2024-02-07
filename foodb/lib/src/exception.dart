import 'dart:convert';
import 'package:http/http.dart';

class AdapterException implements Exception {
  String error;
  String? reason;
  int? code;
  String? rawBody;
  AdapterException({
    required this.error,
    this.reason,
    this.code,
    this.rawBody,
  });

  @override
  String toString() =>
      'AdapterException(error: $error, reason: $reason, rawBody: $rawBody)';

  static fromResponse(Response response) {
    final jsonString = utf8.decode(response.bodyBytes);
    final json = jsonDecode(jsonString);
    return AdapterException(
      rawBody: jsonString,
      error: json['error'],
      reason: json['reason'],
      code: response.statusCode,
    );
  }
}
