import 'dart:io';
import 'package:path/path.dart' as p;

class SdkService {
  String? _sdkPath;
  String? _emulatorExe;
  String? _adbExe;
  String? _flutterExe;

  String? get sdkPath => _sdkPath;
  String? get emulatorExe => _emulatorExe;
  String? get adbExe => _adbExe;
  String? get flutterExe => _flutterExe;

  bool get isReady => _adbExe != null && _emulatorExe != null && _flutterExe != null;

  Future<void> initialize() async {
    await _detectAndroidSdk();
    await _detectFlutter();
  }

  Future<void> _detectAndroidSdk() async {
    // 1. Check environment variables
    final env = Platform.environment;
    final candidates = <String>[];

    if (env.containsKey('ANDROID_HOME') && env['ANDROID_HOME']!.isNotEmpty) {
      candidates.add(env['ANDROID_HOME']!);
    }
    if (env.containsKey('ANDROID_SDK_ROOT') && env['ANDROID_SDK_ROOT']!.isNotEmpty) {
      candidates.add(env['ANDROID_SDK_ROOT']!);
    }

    // 2. Check standard Windows location
    if (Platform.isWindows && env.containsKey('LOCALAPPDATA')) {
      candidates.add(p.join(env['LOCALAPPDATA']!, 'Android', 'Sdk'));
    }

    // 3. User profile fallback
    if (env.containsKey('USERPROFILE')) {
      candidates.add(p.join(env['USERPROFILE']!, 'AppData', 'Local', 'Android', 'Sdk'));
    }

    for (final candidate in candidates) {
      final dir = Directory(candidate);
      if (await dir.exists()) {
        final adb = File(p.join(candidate, 'platform-tools', Platform.isWindows ? 'adb.exe' : 'adb'));
        final emulator = File(p.join(candidate, 'emulator', Platform.isWindows ? 'emulator.exe' : 'emulator'));

        if (await adb.exists() && await emulator.exists()) {
          _sdkPath = candidate;
          _adbExe = adb.path;
          _emulatorExe = emulator.path;
          break;
        }
      }
    }

    // If emulator or adb not found via standard SDK, try system PATH
    _adbExe ??= await _findInPath(Platform.isWindows ? 'adb.exe' : 'adb');
    _emulatorExe ??= await _findInPath(Platform.isWindows ? 'emulator.exe' : 'emulator');
  }

  Future<void> _detectFlutter() async {
    // 1. Try finding flutter in PATH
    final exeName = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final pathFlutter = await _findInPath(exeName);
    if (pathFlutter != null) {
      _flutterExe = pathFlutter;
      return;
    }

    // 2. Common Windows Flutter paths
    final standardLocations = [
      r'C:\src\flutter\bin\flutter.bat',
      r'C:\flutter\bin\flutter.bat',
      r'D:\src\flutter\bin\flutter.bat',
      r'D:\flutter\bin\flutter.bat',
    ];

    for (final loc in standardLocations) {
      if (await File(loc).exists()) {
        _flutterExe = loc;
        return;
      }
    }
  }

  Future<String?> _findInPath(String binaryName) async {
    try {
      final checkCmd = Platform.isWindows ? 'where.exe' : 'which';
      final result = await Process.run(checkCmd, [binaryName], runInShell: true);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && await File(trimmed).exists()) {
            return trimmed;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
