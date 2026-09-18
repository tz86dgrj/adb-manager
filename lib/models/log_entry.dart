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
  final String source; // 'flutter', 'adb', 'emulator', 'system'

  LogEntry({
    DateTime? timestamp,
    required this.message,
    this.level = LogLevel.info,
    this.source = 'system',
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '[${timestamp.toIso8601String()}] [$source] [$level] $message';
}
