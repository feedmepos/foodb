import 'package:flutter/material.dart';

class Telemetry {
  final DateTime startTime;
  final DateTime? endTime;
  final String id;
  final String name;
  final String? reason;

  Telemetry({
    required this.id,
    required this.startTime,
    required this.name,
    this.endTime,
    this.reason,
  });

  // copyWith
  Telemetry copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? reason,
  }) {
    return Telemetry(
      name: name,
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reason: reason ?? this.reason,
    );
  }

  factory Telemetry.start(String name) => Telemetry(
        name: name,
        id: UniqueKey().toString(),
        startTime: DateTime.now(),
      );
}

extension TelemetryExtension on Telemetry {
  Telemetry _end([String? reason]) => copyWith(
        endTime: DateTime.now(),
        reason: reason,
      );

  void end([String? reason]) {
    final endProcess = _end.call(reason);
    print('''
    ProcessId     :: ${endProcess.id}
    ProcessName   :: ${endProcess.name}
    Start         :: ${endProcess.startTime.toIso8601String()}
    End           :: ${endProcess.endTime!.toIso8601String()}
    EndReason     :: ${endProcess.reason}
    Duration      :: ${endProcess.endTime!.difference(endProcess.startTime).inMilliseconds} ms
    ''');
  }
}
