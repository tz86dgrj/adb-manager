import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef BridgeReloadCallback = Future<bool> Function({String? deviceId, bool all});
typedef BridgeRestartCallback = Future<bool> Function({String? deviceId, bool all});
typedef BridgeRunCallback = Future<bool> Function();
typedef BridgeStatusCallback = Map<String, dynamic> Function();
typedef BridgeLogCallback = void Function(String message, {bool isError});

class AgentBridgeService {
  static const int defaultPort = 45678;

  HttpServer? _server;
  int? _port;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  int? get port => _port;
  String? get serverUrl => _isRunning && _port != null ? 'http://127.0.0.1:$_port' : null;

  BridgeReloadCallback? onReload;
  BridgeRestartCallback? onRestart;
  BridgeRunCallback? onRun;
  BridgeStatusCallback? onStatus;
  BridgeLogCallback? onLog;

  AgentBridgeService({
    this.onReload,
    this.onRestart,
    this.onRun,
    this.onStatus,
    this.onLog,
  });

  Future<bool> start({int port = defaultPort}) async {
    if (_isRunning) return true;

    try {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } catch (_) {
        // Fallback to next port or auto-assigned
        try {
          _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port + 1);
        } catch (_) {
          _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        }
      }

      _port = _server!.port;
      _isRunning = true;
      _listen();

      onLog?.call('🤖 [AGENT BRIDGE] Server listening on http://127.0.0.1:$_port (Antigravity Bridge Online)');
      return true;
    } catch (e) {
      _isRunning = false;
      _port = null;
      onLog?.call('Failed to start Agent Bridge server: $e', isError: true);
      return false;
    }
  }

  void _listen() {
    _server?.listen((request) async {
      _handleCors(request);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path.toLowerCase();

      try {
        if (request.method == 'GET' && (path == '/' || path == '/api/status' || path == '/status')) {
          await _handleStatus(request);
        } else if (request.method == 'POST' && (path == '/api/reload' || path == '/reload')) {
          await _handleReload(request);
        } else if (request.method == 'POST' && (path == '/api/restart' || path == '/restart')) {
          await _handleRestart(request);
        } else if (request.method == 'POST' && (path == '/api/run' || path == '/run')) {
          await _handleRun(request);
        } else {
          _sendJson(request, HttpStatus.notFound, {
            'error': 'Endpoint not found',
            'availableEndpoints': [
              'GET  /api/status',
              'POST /api/reload',
              'POST /api/restart',
              'POST /api/run',
            ],
          });
        }
      } catch (e) {
        _sendJson(request, HttpStatus.internalServerError, {'error': e.toString()});
      }
    });
  }

  void _handleCors(HttpRequest request) {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  }

  Future<void> _handleStatus(HttpRequest request) async {
    final statusData = onStatus?.call() ?? {};
    _sendJson(request, HttpStatus.ok, {
      'bridge': 'online',
      'port': _port,
      'timestamp': DateTime.now().toIso8601String(),
      ...statusData,
    });
  }

  Future<void> _handleReload(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final query = request.uri.queryParameters;

    final deviceId = body['deviceId'] as String? ?? query['deviceId'];
    final all = body['all'] == true || query['all'] == 'true';

    onLog?.call('🤖 [ANTIGRAVITY] Auto Hot Reload triggered via Agent Bridge!${deviceId != null ? " ($deviceId)" : all ? " (All Devices)" : ""}');

    final ok = await (onReload?.call(deviceId: deviceId, all: all) ?? Future.value(false));

    _sendJson(request, HttpStatus.ok, {
      'success': ok,
      'action': 'hot-reload',
      'target': deviceId ?? (all ? 'all' : 'active-device'),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleRestart(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final query = request.uri.queryParameters;

    final deviceId = body['deviceId'] as String? ?? query['deviceId'];
    final all = body['all'] == true || query['all'] == 'true';

    onLog?.call('🤖 [ANTIGRAVITY] Auto Hot Restart triggered via Agent Bridge!${deviceId != null ? " ($deviceId)" : all ? " (All Devices)" : ""}');

    final ok = await (onRestart?.call(deviceId: deviceId, all: all) ?? Future.value(false));

    _sendJson(request, HttpStatus.ok, {
      'success': ok,
      'action': 'hot-restart',
      'target': deviceId ?? (all ? 'all' : 'active-device'),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleRun(HttpRequest request) async {
    onLog?.call('🤖 [ANTIGRAVITY] App launch triggered via Agent Bridge!');
    final ok = await (onRun?.call() ?? Future.value(false));

    _sendJson(request, HttpStatus.ok, {
      'success': ok,
      'action': 'run-app',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      if (content.trim().isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _sendJson(HttpRequest request, int statusCode, Map<String, dynamic> data) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data));
    request.response.close();
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      _port = null;
    }
  }
}
