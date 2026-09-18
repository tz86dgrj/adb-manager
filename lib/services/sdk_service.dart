import 'dart:io';
import 'package:path/path.dart' as p;

class SdkService {
  String? _sdkPath;
  String? _emulatorExe;
  String? _adbExe;
  String? _flutterExe;
  String? _avdManagerExe;
  String? _javaHome;

  String? get sdkPath => _sdkPath;
  String? get emulatorExe => _emulatorExe;
  String? get adbExe => _adbExe;
  String? get flutterExe => _flutterExe;
  String? get avdManagerExe => _avdManagerExe;
  String? get javaHome => _javaHome;

  bool get isReady => _adbExe != null && _emulatorExe != null && _flutterExe != null;

  Future<void> initialize() async {
    await _detectAndroidSdk();
    await _detectJava();
    await _detectAvdManager();
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

    // 3. User profile fallback (Windows)
    if (env.containsKey('USERPROFILE')) {
      candidates.add(p.join(env['USERPROFILE']!, 'AppData', 'Local', 'Android', 'Sdk'));
    }

    // 4. Check standard macOS location
    if (Platform.isMacOS && env.containsKey('HOME')) {
      candidates.add(p.join(env['HOME']!, 'Library', 'Android', 'sdk'));
    }

    // 5. Check standard Linux location
    if (Platform.isLinux && env.containsKey('HOME')) {
      candidates.add(p.join(env['HOME']!, 'Android', 'Sdk'));
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

    // 2. Common platform Flutter paths
    final standardLocations = <String>[];
    if (Platform.isWindows) {
      standardLocations.addAll([
        r'C:\src\flutter\bin\flutter.bat',
        r'C:\flutter\bin\flutter.bat',
        r'D:\src\flutter\bin\flutter.bat',
        r'D:\flutter\bin\flutter.bat',
      ]);
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      standardLocations.addAll([
        '/opt/homebrew/bin/flutter',
        '/usr/local/bin/flutter',
        if (home.isNotEmpty) p.join(home, 'flutter', 'bin', 'flutter'),
        if (home.isNotEmpty) p.join(home, 'development', 'flutter', 'bin', 'flutter'),
      ]);
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      standardLocations.addAll([
        '/usr/bin/flutter',
        '/snap/bin/flutter',
        if (home.isNotEmpty) p.join(home, 'flutter', 'bin', 'flutter'),
        if (home.isNotEmpty) p.join(home, 'development', 'flutter', 'bin', 'flutter'),
      ]);
    }

    for (final loc in standardLocations) {
      if (await File(loc).exists()) {
        _flutterExe = loc;
        return;
      }
    }
  }

  Future<void> _detectJava() async {
    final env = Platform.environment;
    if (env.containsKey('JAVA_HOME') && env['JAVA_HOME']!.isNotEmpty) {
      final javaExe = File(p.join(env['JAVA_HOME']!, 'bin', Platform.isWindows ? 'java.exe' : 'java'));
      if (await javaExe.exists()) {
        _javaHome = env['JAVA_HOME'];
        return;
      }
    }

    final candidates = <String>[];
    if (Platform.isWindows) {
      candidates.addAll([
        r'C:\Program Files\Android\Android Studio\jbr',
        r'C:\Program Files\Android\Android Studio\jre',
      ]);
      final javaDir = Directory(r'C:\Program Files\Java');
      if (await javaDir.exists()) {
        try {
          await for (final entity in javaDir.list()) {
            if (entity is Directory) {
              candidates.add(entity.path);
            }
          }
        } catch (_) {}
      }
    } else if (Platform.isMacOS) {
      candidates.addAll([
        '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
        '/Applications/Android Studio.app/Contents/jre/Contents/Home',
      ]);
    }

    for (final candidate in candidates) {
      final javaExe = File(p.join(candidate, 'bin', Platform.isWindows ? 'java.exe' : 'java'));
      if (await javaExe.exists()) {
        _javaHome = candidate;
        return;
      }
    }

    final pathJava = await _findInPath(Platform.isWindows ? 'java.exe' : 'java');
    if (pathJava != null) {
      _javaHome = p.dirname(p.dirname(pathJava));
    }
  }

  Future<void> _detectAvdManager() async {
    final exeName = Platform.isWindows ? 'avdmanager.bat' : 'avdmanager';

    if (_sdkPath != null) {
      final cmdlineToolsDir = Directory(p.join(_sdkPath!, 'cmdline-tools'));
      if (await cmdlineToolsDir.exists()) {
        try {
          final latestExe = File(p.join(cmdlineToolsDir.path, 'latest', 'bin', exeName));
          if (await latestExe.exists()) {
            _avdManagerExe = latestExe.path;
            return;
          }
          await for (final entity in cmdlineToolsDir.list()) {
            if (entity is Directory) {
              final exe = File(p.join(entity.path, 'bin', exeName));
              if (await exe.exists()) {
                _avdManagerExe = exe.path;
                return;
              }
            }
          }
        } catch (_) {}
      }

      final legacyExe = File(p.join(_sdkPath!, 'tools', 'bin', exeName));
      if (await legacyExe.exists()) {
        _avdManagerExe = legacyExe.path;
        return;
      }
    }

    _avdManagerExe ??= await _findInPath(exeName);
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
