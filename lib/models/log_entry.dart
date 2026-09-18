enum LogLevel {
  info,
  success,
  warning,
  error,
  system,
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String source; // 'flutter', 'adb', 'emulator', 'system', 'build', 'bridge'
  final String? deviceId;

  LogEntry({
    DateTime? timestamp,
    required this.message,
    this.level = LogLevel.info,
    this.source = 'system',
    this.deviceId,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [$source]${deviceId != null ? " [$deviceId]" : ""} [$level] $message';
}
