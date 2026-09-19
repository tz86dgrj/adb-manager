import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adb_device.dart';
import '../models/apk_build_options.dart';
import '../models/avd_creation_options.dart';
import '../models/avd_info.dart';
import '../models/device_session.dart';
import '../models/launch_config.dart';
import '../models/log_entry.dart';
import '../services/adb_service.dart';
import '../services/agent_bridge_service.dart';
import '../services/apk_build_service.dart';
import '../services/avd_service.dart';
import '../services/flutter_runner_service.dart';
import '../services/sdk_service.dart';

class AppState extends ChangeNotifier {
  final SdkService sdkService;
  late final AvdService avdService;
  late final AdbService adbService;
  late final FlutterRunnerService runnerService;
  late final ApkBuildService apkBuildService;
  late final AgentBridgeService agentBridgeService;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  LaunchConfig _launchConfig = const LaunchConfig();
  LaunchConfig get launchConfig => _launchConfig;

  List<AvdInfo> _avds = [];
  List<AvdInfo> get avds => _avds;

  List<AdbDevice> _connectedDevices = [];
  List<AdbDevice> get connectedDevices => _connectedDevices;

  String? _selectedDeviceId;
  String? get selectedDeviceId => _selectedDeviceId;

  DeviceSession? get activeSession =>
      _selectedDeviceId != null ? runnerService.getOrCreateSession(_selectedDeviceId!) : null;

  String? get debugUri => activeSession?.debugUri;

  DeviceSession getSession(String deviceId) => runnerService.getOrCreateSession(deviceId);
  bool isDeviceRunning(String deviceId) => runnerService.getOrCreateSession(deviceId).isRunning;
  bool isDeviceStarting(String deviceId) => runnerService.getOrCreateSession(deviceId).isStarting;

  String? _currentProjectPath;
  String? get currentProjectPath => _currentProjectPath;

  List<String> _recentProjects = [];
  List<String> get recentProjects => _recentProjects;

  String? _detectedPackageName;
  String? get detectedPackageName => _detectedPackageName;

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  String _logFilter = '';
  String get logFilter => _logFilter;

  LogLevel? _levelFilter;
  LogLevel? get levelFilter => _levelFilter;

  bool _autoScroll = true;
  bool get autoScroll => _autoScroll;

  String? _creatingAvdName;
  String? get creatingAvdName => _creatingAvdName;

  String? _creatingAvdDetails;
  String? get creatingAvdDetails => _creatingAvdDetails;

  bool get isCreatingAvd => _creatingAvdName != null;

  final StreamController<AvdCreationResult> _avdEventController = StreamController<AvdCreationResult>.broadcast();
  Stream<AvdCreationResult> get avdEvents => _avdEventController.stream;

  Timer? _pollTimer;
  StreamSubscription? _runnerStateSub;
  StreamSubscription? _runnerLogSub;
  StreamSubscription? _buildLogSub;

  AppState(this.sdkService) {
    avdService = AvdService(sdkService);
    adbService = AdbService(sdkService);
    runnerService = FlutterRunnerService(sdkService);
    apkBuildService = ApkBuildService(sdkService);
    agentBridgeService = AgentBridgeService(
      onReload: ({String? deviceId, bool all = false}) async {
        if (all) {
          await reloadAllDevices();
          return true;
        } else {
          final target = deviceId ?? _selectedDeviceId;
          if (target != null) {
            await hotReload(deviceId: target);
            return true;
          }
          return false;
        }
      },
      onRestart: ({String? deviceId, bool all = false}) async {
        if (all) {
          await restartAllDevices();
          return true;
        } else {
          final target = deviceId ?? _selectedDeviceId;
          if (target != null) {
            await hotRestart(deviceId: target);
            return true;
          }
          return false;
        }
      },
      onRun: () async {
        await runFlutterApp();
        return true;
      },
      onStatus: () {
        return {
          'projectPath': _currentProjectPath,
          'packageName': _detectedPackageName,
          'selectedDeviceId': _selectedDeviceId,
          'connectedDevices': _connectedDevices.map((d) => d.id).toList(),
          'runningDevices': runnerService.runningSessions.map((s) => s.deviceId).toList(),
          'isRunning': runnerService.isRunning,
          'debugUri': debugUri,
        };
      },
      onLog: (msg, {bool isError = false}) {
        _addLog(LogEntry(
          message: msg,
          level: isError ? LogLevel.error : LogLevel.system,
          source: 'bridge',
        ));
      },
    );
  }

  bool get isAgentBridgeOnline => agentBridgeService.isRunning;
  int? get agentBridgePort => agentBridgeService.port;

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    await sdkService.initialize();

    // Listen to Flutter runner events across devices
    _runnerStateSub = runnerService.sessionUpdatesStream.listen((_) {
      notifyListeners();
    });

    _runnerLogSub = runnerService.logStream.listen((entry) {
      _addLog(entry);
    });

    _buildLogSub = apkBuildService.outputStream.listen((line) {
      _addLog(LogEntry(
        message: line,
        level: line.startsWith('[ERROR]') ? LogLevel.error : LogLevel.info,
        source: 'build',
      ));
    });

    // Start Antigravity Agent Bridge Server
    await agentBridgeService.start();

    // Load persisted settings
    await _loadPreferences();

    // Initial scan of AVDs and devices
    await refreshDevices();

    // Start background polling for device changes (every 3 seconds)
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefreshDevices();
    });

    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentProjects = prefs.getStringList('recent_projects') ?? [];
      final lastProj = prefs.getString('last_project');
      if (lastProj != null && await Directory(lastProj).exists()) {
        _currentProjectPath = lastProj;
        await _updatePackageName();
        await _loadLaunchConfig();
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_projects', _recentProjects);
      if (_currentProjectPath != null) {
        await prefs.setString('last_project', _currentProjectPath!);
      }
    } catch (_) {}
  }

  Future<void> refreshDevices() async {
    _avds = await avdService.listAvds();
    _connectedDevices = await adbService.getConnectedDevices();

    // Reconcile AVD running status with connected devices
    final runningIds = _connectedDevices.map((d) => d.id).toSet();
    _avds = _avds.map((avd) {
      // Typically emulator-5554, emulator-5556, etc.
      final isRunning = runningIds.isNotEmpty; // Can be matched more granularly
      return avd.copyWith(isRunning: isRunning);
    }).toList();

    // Auto-select first device if none selected or selected is gone
    if (_selectedDeviceId == null || !_connectedDevices.any((d) => d.id == _selectedDeviceId)) {
      if (_connectedDevices.isNotEmpty) {
        _selectedDeviceId = _connectedDevices.first.id;
      } else {
        _selectedDeviceId = null;
      }
    }

    notifyListeners();
  }

  Future<void> _silentRefreshDevices() async {
    final updatedDevices = await adbService.getConnectedDevices();
    if (updatedDevices.length != _connectedDevices.length ||
        !listEquals(updatedDevices.map((d) => d.id).toList(), _connectedDevices.map((d) => d.id).toList())) {
      _connectedDevices = updatedDevices;
      if (_selectedDeviceId == null && _connectedDevices.isNotEmpty) {
        _selectedDeviceId = _connectedDevices.first.id;
      }
      notifyListeners();
    }
  }

  void selectDevice(String? deviceId) {
    _selectedDeviceId = deviceId;
    notifyListeners();
  }

  Future<void> selectProject(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      _currentProjectPath = path;
      _recentProjects.remove(path);
      _recentProjects.insert(0, path);
      if (_recentProjects.length > 8) {
        _recentProjects = _recentProjects.sublist(0, 8);
      }
      await _updatePackageName();
      await _loadLaunchConfig();
      await _savePreferences();
      _addLog(LogEntry(
        message: 'Loaded project: $path (Package: ${_detectedPackageName ?? "Unknown"})'
            '${_launchConfig.dartDefineFromFile != null ? " [Auto-defines: ${_launchConfig.dartDefineFromFile}]" : ""}',
        level: LogLevel.system,
      ));
      notifyListeners();
    }
  }

  void updateLaunchConfig(LaunchConfig config) {
    _launchConfig = config;
    _saveLaunchConfig();
    notifyListeners();
  }

  Future<void> _loadLaunchConfig() async {
    if (_currentProjectPath == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cfg_${_currentProjectPath!.hashCode}';
      final saved = prefs.getString(key);
      if (saved != null) {
        _launchConfig = LaunchConfig.fromJson(saved);
      } else {
        await _autoDetectLaunchConfig();
      }
    } catch (_) {
      await _autoDetectLaunchConfig();
    }
  }

  Future<void> _saveLaunchConfig() async {
    if (_currentProjectPath == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cfg_${_currentProjectPath!.hashCode}';
      await prefs.setString(key, _launchConfig.toJson());
    } catch (_) {}
  }

  Future<void> _autoDetectLaunchConfig() async {
    if (_currentProjectPath == null) return;
    String? definesPath;
    final candidates = [
      'dart_defines.json',
      'dart-defines.json',
      'env.json',
      'config/dart_defines.json',
      'environments/dart_defines.json',
    ];

    for (final cand in candidates) {
      final file = File(p.join(_currentProjectPath!, cand));
      if (await file.exists()) {
        definesPath = cand;
        break;
      }
    }

    _launchConfig = LaunchConfig(
      dartDefineFromFile: definesPath,
      target: 'lib/main.dart',
      mode: 'debug',
    );
  }

  Future<void> _updatePackageName() async {
    if (_currentProjectPath != null) {
      _detectedPackageName = await adbService.detectPackageName(_currentProjectPath!);
    } else {
      _detectedPackageName = null;
    }
  }

  Future<void> launchAvd(String avdName, {bool coldBoot = false, bool wipeData = false}) async {
    _addLog(LogEntry(
      message: 'Launching AVD: $avdName${coldBoot ? " (Cold Boot)" : ""}${wipeData ? " (Wipe Data)" : ""}...',
      level: LogLevel.system,
    ));
    final ok = await avdService.launchAvd(avdName, coldBoot: coldBoot, wipeData: wipeData);
    if (!ok) {
      _addLog(LogEntry(message: 'Failed to launch AVD $avdName', level: LogLevel.error));
    }
  }

  void startBackgroundAvdCreation({
    required String name,
    required String deviceProfileId,
    required String systemImagePackage,
    required String details,
    int ramMb = 2048,
    int internalStorageMb = 6144,
  }) {
    _creatingAvdName = name;
    _creatingAvdDetails = details;
    notifyListeners();

    _addLog(LogEntry(
      message: 'Background creation started for "$name" ($details)...',
      level: LogLevel.system,
    ));

    () async {
      final result = await avdService.createAvd(
        name: name,
        deviceProfileId: deviceProfileId,
        systemImagePackage: systemImagePackage,
        ramMb: ramMb,
        internalStorageMb: internalStorageMb,
      );

      _creatingAvdName = null;
      _creatingAvdDetails = null;
      notifyListeners();

      if (result.success) {
        _addLog(LogEntry(message: result.message, level: LogLevel.success));
        await refreshDevices();
      } else {
        _addLog(LogEntry(message: result.message, level: LogLevel.error));
      }

      _avdEventController.add(result);
    }();
  }

  Future<AvdCreationResult> createAvd({
    required String name,
    required String deviceProfileId,
    required String systemImagePackage,
    int ramMb = 2048,
    int internalStorageMb = 6144,
  }) async {
    _addLog(LogEntry(
      message: 'Creating virtual device "$name" ($deviceProfileId)...',
      level: LogLevel.system,
    ));

    final result = await avdService.createAvd(
      name: name,
      deviceProfileId: deviceProfileId,
      systemImagePackage: systemImagePackage,
      ramMb: ramMb,
      internalStorageMb: internalStorageMb,
    );

    if (result.success) {
      _addLog(LogEntry(message: result.message, level: LogLevel.system));
      await refreshDevices();
    } else {
      _addLog(LogEntry(message: result.message, level: LogLevel.error));
    }

    return result;
  }

  Future<bool> deleteAvd(String avdName) async {
    _addLog(LogEntry(message: 'Deleting AVD "$avdName"...', level: LogLevel.system));
    final ok = await avdService.deleteAvd(avdName);
    if (ok) {
      _addLog(LogEntry(message: 'Deleted AVD "$avdName" successfully.', level: LogLevel.system));
      await refreshDevices();
    } else {
      _addLog(LogEntry(message: 'Failed to delete AVD "$avdName".', level: LogLevel.error));
    }
    return ok;
  }

  Future<void> killSelectedDevice() async {
    if (_selectedDeviceId == null) return;
    _addLog(LogEntry(message: 'Shutting down device $_selectedDeviceId...', level: LogLevel.system));
    await avdService.killEmulator(_selectedDeviceId!);
    await Future.delayed(const Duration(seconds: 1));
    await refreshDevices();
  }

  Future<void> runFlutterApp({String? deviceId, LaunchConfig? overrideConfig}) async {
    if (_currentProjectPath == null) {
      _addLog(LogEntry(message: 'No project selected. Please pick a Flutter project folder first.', level: LogLevel.warning));
      return;
    }

    final targetDev = deviceId ?? _selectedDeviceId;
    if (targetDev == null) {
      _addLog(LogEntry(message: 'No target device connected. Please launch an emulator or connect a device.', level: LogLevel.warning));
      return;
    }

    final configToUse = overrideConfig ?? _launchConfig;

    await runnerService.startApp(
      projectPath: _currentProjectPath!,
      deviceId: targetDev,
      config: configToUse,
    );
  }

  Future<void> hotReload({String? deviceId}) async {
    final targetDev = deviceId ?? _selectedDeviceId;
    if (targetDev == null) return;
    await runnerService.hotReload(targetDev);
  }

  Future<void> hotRestart({String? deviceId}) async {
    final targetDev = deviceId ?? _selectedDeviceId;
    if (targetDev == null) return;
    await runnerService.hotRestart(targetDev);
  }

  Future<void> stopFlutterApp({String? deviceId}) async {
    final targetDev = deviceId ?? _selectedDeviceId;
    if (targetDev == null) return;
    await runnerService.stopApp(targetDev);
  }

  Future<void> reloadAllDevices() async {
    _addLog(LogEntry(message: '⚡ Broadcasting Hot Reload to ALL active devices...', level: LogLevel.system));
    await runnerService.reloadAll();
  }

  Future<void> restartAllDevices() async {
    _addLog(LogEntry(message: '🔄 Broadcasting Hot Restart to ALL active devices...', level: LogLevel.system));
    await runnerService.restartAll();
  }

  Future<void> fixGradleLocks() async {
    if (_currentProjectPath == null) {
      _addLog(LogEntry(message: 'Select a Flutter project before cleaning locks.', level: LogLevel.warning));
      return;
    }
    _addLog(LogEntry(message: '🧹 Running Gradle lock cleanup & clearing intermediate build cache...', level: LogLevel.system));
    final report = await adbService.fixGradleLocks(_currentProjectPath!);
    _addLog(LogEntry(message: '✅ $report', level: LogLevel.success));
  }

  Future<void> clearAppData() async {
    if (_selectedDeviceId == null || _detectedPackageName == null) {
      _addLog(LogEntry(message: 'Need active device and detected package name to clear data.', level: LogLevel.warning));
      return;
    }
    final dev = _selectedDeviceId!;
    _addLog(LogEntry(
      message: 'Clearing app data for $_detectedPackageName on $dev...',
      level: LogLevel.system,
      source: 'adb',
      deviceId: dev,
    ));
    final ok = await adbService.clearAppData(dev, _detectedPackageName!);
    if (ok) {
      _addLog(LogEntry(
        message: '✅ Successfully cleared app data for $_detectedPackageName',
        level: LogLevel.success,
        source: 'adb',
        deviceId: dev,
      ));
    } else {
      _addLog(LogEntry(
        message: 'Failed to clear app data for $_detectedPackageName',
        level: LogLevel.error,
        source: 'adb',
        deviceId: dev,
      ));
    }
  }

  Future<void> toggleDeviceDarkMode(bool dark) async {
    if (_selectedDeviceId == null) return;
    final dev = _selectedDeviceId!;
    _addLog(LogEntry(
      message: 'Setting UI mode on $dev to ${dark ? "Dark" : "Light"}...',
      level: LogLevel.system,
      source: 'adb',
      deviceId: dev,
    ));
    final ok = await adbService.toggleUiMode(dev, dark);
    if (ok) {
      _addLog(LogEntry(
        message: '✅ UI Mode updated to ${dark ? "Dark" : "Light"}',
        level: LogLevel.success,
        source: 'adb',
        deviceId: dev,
      ));
    }
  }

  Future<void> captureScreenshot() async {
    if (_selectedDeviceId == null) return;
    final dev = _selectedDeviceId!;
    _addLog(LogEntry(
      message: 'Capturing screenshot from $dev...',
      level: LogLevel.system,
      source: 'adb',
      deviceId: dev,
    ));
    final path = await adbService.captureScreenshot(dev);
    if (path != null) {
      _addLog(LogEntry(
        message: '📸 Screenshot saved: $path',
        level: LogLevel.success,
        source: 'adb',
        deviceId: dev,
      ));
    } else {
      _addLog(LogEntry(
        message: 'Failed to capture screenshot',
        level: LogLevel.error,
        source: 'adb',
        deviceId: dev,
      ));
    }
  }

  Future<bool> installApkToActiveDevice(String apkPath, {String? targetDeviceId}) async {
    final dev = targetDeviceId ?? _selectedDeviceId;
    if (dev == null) {
      _addLog(LogEntry(message: 'No device selected to install APK.', level: LogLevel.warning));
      return false;
    }
    _addLog(LogEntry(
      message: '📲 Installing APK on $dev: $apkPath...',
      level: LogLevel.system,
      source: 'adb',
      deviceId: dev,
    ));
    final ok = await adbService.installApk(dev, apkPath);
    if (ok) {
      _addLog(LogEntry(
        message: '✅ APK installed successfully on $dev',
        level: LogLevel.success,
        source: 'adb',
        deviceId: dev,
      ));
    } else {
      _addLog(LogEntry(
        message: '❌ Failed to install APK on $dev',
        level: LogLevel.error,
        source: 'adb',
        deviceId: dev,
      ));
    }
    return ok;
  }

  Future<bool> launchDeepLink(String url, {String? targetDeviceId}) async {
    final dev = targetDeviceId ?? _selectedDeviceId;
    if (dev == null) {
      _addLog(LogEntry(message: 'No device selected to launch deep link.', level: LogLevel.warning));
      return false;
    }
    _addLog(LogEntry(
      message: '🔗 Dispatching deep link on $dev: $url',
      level: LogLevel.system,
      source: 'adb',
      deviceId: dev,
    ));
    final ok = await adbService.launchDeepLink(dev, url);
    if (ok) {
      _addLog(LogEntry(
        message: '✅ Deep link intent dispatched to $dev',
        level: LogLevel.success,
        source: 'adb',
        deviceId: dev,
      ));
    } else {
      _addLog(LogEntry(
        message: '❌ Failed to dispatch deep link on $dev',
        level: LogLevel.error,
        source: 'adb',
        deviceId: dev,
      ));
    }
    return ok;
  }

  Future<bool> sendClipboardToDevice(String text, {String? targetDeviceId}) async {
    final dev = targetDeviceId ?? _selectedDeviceId;
    if (dev == null) {
      _addLog(LogEntry(message: 'No device selected to send clipboard.', level: LogLevel.warning));
      return false;
    }
    _addLog(LogEntry(
      message: '📋 Sending clipboard text to $dev...',
      level: LogLevel.system,
      source: 'adb',
      deviceId: dev,
    ));
    final ok = await adbService.sendClipboardText(dev, text);
    if (ok) {
      _addLog(LogEntry(
        message: '✅ Clipboard text injected into $dev',
        level: LogLevel.success,
        source: 'adb',
        deviceId: dev,
      ));
    } else {
      _addLog(LogEntry(
        message: '❌ Failed to inject text into $dev',
        level: LogLevel.error,
        source: 'adb',
        deviceId: dev,
      ));
    }
    return ok;
  }

  void _addLog(LogEntry entry, {String? targetDeviceId}) {
    _logs.add(entry);
    if (_logs.length > 1500) {
      _logs.removeRange(0, 200);
    }
    final devId = targetDeviceId ?? entry.deviceId;
    if (devId != null && entry.source != 'flutter') {
      runnerService.getOrCreateSession(devId).addLog(entry);
    }
    notifyListeners();
  }

  void setLogFilter(String filter) {
    _logFilter = filter;
    notifyListeners();
  }

  void setLevelFilter(LogLevel? level) {
    _levelFilter = level;
    notifyListeners();
  }

  void setAutoScroll(bool auto) {
    _autoScroll = auto;
    notifyListeners();
  }

  void clearDeviceLogs(String deviceId) {
    runnerService.getOrCreateSession(deviceId).clearLogs();
    _logs.removeWhere((l) => l.deviceId == deviceId);
    notifyListeners();
  }

  void clearLogs({String? deviceId}) {
    final target = deviceId ?? _selectedDeviceId;
    if (target != null) {
      clearDeviceLogs(target);
    } else {
      _logs.clear();
      notifyListeners();
    }
  }

  void clearAllLogs() {
    _logs.clear();
    for (final s in runnerService.sessions.values) {
      s.clearLogs();
    }
    notifyListeners();
  }

  Future<ApkBuildResult> buildApk(ApkBuildOptions options) async {
    if (_currentProjectPath == null) {
      const err = ApkBuildResult(
        success: false,
        errorMessage: 'Please open a Flutter project first.',
      );
      _addLog(LogEntry(message: err.errorMessage!, level: LogLevel.error));
      return err;
    }

    _addLog(LogEntry(
      message: '📦 Initiating ${options.target == ApkBuildTarget.apk ? "APK" : "AppBundle"} build (${options.mode.name.toUpperCase()})...',
      level: LogLevel.system,
    ));

    final result = await apkBuildService.startBuild(
      projectPath: _currentProjectPath!,
      options: options,
    );

    if (result.success) {
      _addLog(LogEntry(
        message: '🎉 Build successful in ${result.duration.inSeconds}s! Generated: ${result.primaryOutputFile ?? "artifacts"} (${result.formattedFileSize})',
        level: LogLevel.success,
      ));
    } else {
      _addLog(LogEntry(
        message: '❌ Build failed: ${result.errorMessage ?? "Unknown error"}',
        level: LogLevel.error,
      ));
    }

    return result;
  }

  Future<void> cancelApkBuild() async {
    await apkBuildService.cancelBuild();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _runnerStateSub?.cancel();
    _runnerLogSub?.cancel();
    _buildLogSub?.cancel();
    _avdEventController.close();
    agentBridgeService.stop();
    runnerService.dispose();
    super.dispose();
  }
}
