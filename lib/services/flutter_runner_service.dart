import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/device_session.dart';
import '../models/launch_config.dart';
import '../models/log_entry.dart';
import 'sdk_service.dart';

class FlutterRunnerService {
  final SdkService _sdkService;

  final Map<String, DeviceSession> _sessions = {};
  final _sessionUpdatesController = StreamController<DeviceSession>.broadcast();
  final _logController = StreamController<LogEntry>.broadcast();

  FlutterRunnerService(this._sdkService);

  Map<String, DeviceSession> get sessions => Map.unmodifiable(_sessions);
  Stream<DeviceSession> get sessionUpdatesStream => _sessionUpdatesController.stream;
  Stream<LogEntry> get logStream => _logController.stream;

  List<DeviceSession> get runningSessions =>
      _sessions.values.where((s) => s.isRunning).toList();

  bool get hasRunningSessions => runningSessions.isNotEmpty;
  bool get isRunning => hasRunningSessions;

  DeviceSession getOrCreateSession(String deviceId) {
    return _sessions.putIfAbsent(
      deviceId,
      () => DeviceSession(deviceId: deviceId),
    );
  }

  void _notifySession(DeviceSession session) {
    _sessionUpdatesController.add(session);
  }

  void _addLog(
    DeviceSession session,
    String message, {
    LogLevel level = LogLevel.info,
    String source = 'flutter',
  }) {
    final entry = LogEntry(
      message: message,
      level: level,
      source: source,
    );
    session.addLog(entry);
    _logController.add(entry);
    _notifySession(session);
  }

  Future<bool> startApp({
    required String projectPath,
    required String deviceId,
    LaunchConfig config = const LaunchConfig(),
  }) async {
    final session = getOrCreateSession(deviceId);
    if (session.isRunning || session.isStarting) {
      _addLog(session, 'App is already running or launching on $deviceId.', level: LogLevel.warning);
      return false;
    }

    final flutterExe = _sdkService.flutterExe;
    if (flutterExe == null) {
      _addLog(session, 'Flutter executable not found. Check SDK configuration.', level: LogLevel.error);
      return false;
    }

    session.state = SessionRunState.starting;
    session.appId = null;
    session.debugUri = null;
    session.config = config;
    _notifySession(session);

    final args = <String>[
      'run',
      '-d',
      deviceId,
      '--machine',
    ];

    if (config.target != null && config.target!.trim().isNotEmpty) {
      args.addAll(['-t', config.target!.trim()]);
    }

    if (config.flavor != null && config.flavor!.trim().isNotEmpty) {
      args.addAll(['--flavor', config.flavor!.trim()]);
    }

    if (config.dartDefineFromFile != null && config.dartDefineFromFile!.trim().isNotEmpty) {
      args.add('--dart-define-from-file=${config.dartDefineFromFile!.trim()}');
    }

    if (config.mode == 'profile') {
      args.add('--profile');
    } else if (config.mode == 'release') {
      args.add('--release');
    }

    if (config.additionalArgs != null && config.additionalArgs!.trim().isNotEmpty) {
      final parts = config.additionalArgs!.trim().split(RegExp(r'\s+'));
      args.addAll(parts.where((p) => p.isNotEmpty));
    }

    _addLog(session, '[$deviceId] Launching: flutter ${args.join(' ')}', level: LogLevel.system);
    _addLog(session, '[$deviceId] Working Directory: $projectPath', level: LogLevel.system);

    try {
      final process = await Process.start(
        flutterExe,
        args,
        workingDirectory: projectPath,
        runInShell: true,
      );

      session.process = process;
      session.state = SessionRunState.building;
      _notifySession(session);

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _handleStdoutLine(session, line);
      }, onError: (err) {
        _addLog(session, '[$deviceId] stdout error: $err', level: LogLevel.error);
      });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog(session, '[$deviceId] $line', level: LogLevel.error);
      });

      process.exitCode.then((code) {
        _addLog(
          session,
          '[$deviceId] Flutter process terminated (exit code $code)',
          level: code == 0 ? LogLevel.info : LogLevel.warning,
        );
        session.process = null;
        session.appId = null;
        session.state = SessionRunState.stopped;
        _notifySession(session);
      });

      return true;
    } catch (e) {
      _addLog(session, '[$deviceId] Failed to launch: $e', level: LogLevel.error);
      session.state = SessionRunState.stopped;
      session.process = null;
      _notifySession(session);
      return false;
    }
  }

  void _handleStdoutLine(DeviceSession session, String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return;

    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        final dynamic decoded = jsonDecode(line);
        if (decoded is List && decoded.isNotEmpty) {
          final eventObj = decoded[0];
          if (eventObj is Map<String, dynamic>) {
            _processMachineEvent(session, eventObj);
            return;
          }
        }
      } catch (_) {}
    }

    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final dynamic decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          _processMachineEvent(session, decoded);
          return;
        }
      } catch (_) {}
    }

    _addLog(session, line, level: LogLevel.info);
  }

  void _processMachineEvent(DeviceSession session, Map<String, dynamic> msg) {
    if (msg['event'] == 'app.progress') {
      final params = msg['params'] as Map<String, dynamic>?;
      final message = params?['message'] as String?;
      final finished = params?['finished'] == true;
      if (message != null && !finished) {
        _addLog(session, '⏳ $message', level: LogLevel.system);
      }
      return;
    }

    if (msg['event'] == 'app.start') {
      final params = msg['params'] as Map<String, dynamic>?;
      session.appId = params?['appId'] as String?;
      _addLog(session, '🚀 App initializing on ${session.deviceId} (ID: ${session.appId})...', level: LogLevel.system);
      _notifySession(session);
      return;
    }

    if (msg['event'] == 'app.started') {
      session.state = SessionRunState.running;
      _addLog(session, '✅ App running and synchronized on ${session.deviceId}!', level: LogLevel.success);
      _notifySession(session);
      return;
    }

    if (msg['event'] == 'app.debugPort') {
      final params = msg['params'] as Map<String, dynamic>?;
      session.debugUri = params?['wsUri'] as String?;
      if (session.debugUri != null) {
        _addLog(session, '🔗 Dart VM Service on ${session.deviceId}: ${session.debugUri}', level: LogLevel.info);
      }
      _notifySession(session);
      return;
    }

    if (msg['event'] == 'app.log') {
      final params = msg['params'] as Map<String, dynamic>?;
      final logText = params?['log'] as String? ?? '';
      final isError = params?['error'] == true;
      _addLog(session, logText.trimRight(), level: isError ? LogLevel.error : LogLevel.info);
      return;
    }

    if (msg['event'] == 'app.stop') {
      session.state = SessionRunState.stopped;
      _addLog(session, '🛑 App stopped on ${session.deviceId}.', level: LogLevel.system);
      _notifySession(session);
      return;
    }

    if (msg.containsKey('id')) {
      final error = msg['error'];
      if (error != null) {
        _addLog(session, 'Command error: $error', level: LogLevel.error);
        session.state = SessionRunState.running;
      } else {
        final result = msg['result'];
        if (session.state == SessionRunState.reloading) {
          session.state = SessionRunState.running;
          _addLog(session, '⚡ Hot Reload complete on ${session.deviceId}! $result', level: LogLevel.success);
        } else if (session.state == SessionRunState.restarting) {
          session.state = SessionRunState.running;
          _addLog(session, '🔄 Hot Restart complete on ${session.deviceId}! $result', level: LogLevel.success);
        }
      }
      _notifySession(session);
    }
  }

  Future<bool> hotReload(String deviceId) async {
    final session = _sessions[deviceId];
    if (session == null || session.process == null) return false;

    session.state = SessionRunState.reloading;
    _notifySession(session);
    _addLog(session, '⚡ [${session.deviceId}] Requesting Hot Reload...', level: LogLevel.system);

    if (session.appId != null) {
      final req = jsonEncode([
        {
          'id': session.requestId++,
          'method': 'app.restart',
          'params': {
            'appId': session.appId,
            'fullRestart': false,
            'pause': false,
          },
        }
      ]);
      session.process!.stdin.writeln(req);
    } else {
      session.process!.stdin.writeln('r');
    }
    return true;
  }

  Future<bool> hotRestart(String deviceId) async {
    final session = _sessions[deviceId];
    if (session == null || session.process == null) return false;

    session.state = SessionRunState.restarting;
    _notifySession(session);
    _addLog(session, '🔄 [${session.deviceId}] Requesting Hot Restart...', level: LogLevel.system);

    if (session.appId != null) {
      final req = jsonEncode([
        {
          'id': session.requestId++,
          'method': 'app.restart',
          'params': {
            'appId': session.appId,
            'fullRestart': true,
            'pause': false,
          },
        }
      ]);
      session.process!.stdin.writeln(req);
    } else {
      session.process!.stdin.writeln('R');
    }
    return true;
  }

  Future<bool> stopApp(String deviceId) async {
    final session = _sessions[deviceId];
    if (session == null || session.process == null) return false;

    _addLog(session, 'Stopping Flutter app on ${session.deviceId}...', level: LogLevel.system);

    if (session.appId != null) {
      final req = jsonEncode([
        {
          'id': session.requestId++,
          'method': 'app.stop',
          'params': {'appId': session.appId},
        }
      ]);
      session.process!.stdin.writeln(req);
    } else {
      session.process!.stdin.writeln('q');
    }

    final p = session.process;
    Future.delayed(const Duration(seconds: 3), () {
      if (p != null) {
        try {
          p.kill();
        } catch (_) {}
        if (session.process == p) {
          session.process = null;
          session.state = SessionRunState.stopped;
          _notifySession(session);
        }
      }
    });

    return true;
  }

  Future<void> reloadAll() async {
    final running = runningSessions;
    for (final s in running) {
      await hotReload(s.deviceId);
    }
  }

  Future<void> restartAll() async {
    final running = runningSessions;
    for (final s in running) {
      await hotRestart(s.deviceId);
    }
  }

  void dispose() {
    for (final s in _sessions.values) {
      s.process?.kill();
    }
    _sessionUpdatesController.close();
    _logController.close();
  }
}
