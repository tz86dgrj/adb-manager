import 'dart:io';
import 'launch_config.dart';
import 'log_entry.dart';

enum SessionRunState {
  stopped,
  starting,
  building,
  running,
  reloading,
  restarting,
}

class DeviceSession {
  final String deviceId;
  Process? process;
  String? appId;
  String? debugUri;
  SessionRunState state;
  final List<LogEntry> logs;
  LaunchConfig config;
  int requestId;

  DeviceSession({
    required this.deviceId,
    this.process,
    this.appId,
    this.debugUri,
    this.state = SessionRunState.stopped,
    List<LogEntry>? logs,
    this.config = const LaunchConfig(),
    this.requestId = 1,
  }) : logs = logs ?? [];

  bool get isRunning =>
      state == SessionRunState.running ||
      state == SessionRunState.reloading ||
      state == SessionRunState.restarting;

  bool get isStarting =>
      state == SessionRunState.starting ||
      state == SessionRunState.building;

  bool get canReload => isRunning;

  void addLog(LogEntry entry) {
    logs.add(entry);
    if (logs.length > 1500) {
      logs.removeRange(0, 200);
    }
  }

  void clearLogs() {
    logs.clear();
  }
}
