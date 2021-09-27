class AdapterException implements Exception {
  String error;
  String? reason;
  AdapterException({required this.error, this.reason});

  @override
  String toString() => 'AdapterException(error: $error, reason: $reason)';
}
