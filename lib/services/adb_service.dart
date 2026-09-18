import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/adb_device.dart';
import 'sdk_service.dart';

class AdbService {
  final SdkService _sdkService;

  AdbService(this._sdkService);

  Future<List<AdbDevice>> getConnectedDevices() async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return [];

    try {
      final result = await Process.run(adbExe, ['devices', '-l']);
      if (result.exitCode != 0) return [];

      final lines = LineSplitter.split(result.stdout as String);
      final devices = <AdbDevice>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('List of devices attached') || trimmed.startsWith('*')) {
          continue;
        }

        // Example line:
        // emulator-5554          device product:sdk_gphone16k_x86_64 model:sdk_gphone16k_x86_64 device:emu64x transport_id:1
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final id = parts[0];
          final state = parts[1];

          String? model;
          String? product;
          String? device;
          String? transportId;

          for (int i = 2; i < parts.length; i++) {
            final part = parts[i];
            if (part.startsWith('model:')) {
              model = part.substring('model:'.length);
            } else if (part.startsWith('product:')) {
              product = part.substring('product:'.length);
            } else if (part.startsWith('device:')) {
              device = part.substring('device:'.length);
            } else if (part.startsWith('transport_id:')) {
              transportId = part.substring('transport_id:'.length);
            }
          }

          devices.add(AdbDevice(
            id: id,
            state: state,
            model: model,
            product: product,
            device: device,
            transportId: transportId,
            isEmulator: id.startsWith('emulator-'),
          ));
        }
      }

      return devices;
    } catch (_) {
      return [];
    }
  }

  Future<bool> clearAppData(String deviceId, String packageName) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'shell', 'pm', 'clear', packageName]);
      return result.exitCode == 0 && (result.stdout as String).contains('Success');
    } catch (_) {
      return false;
    }
  }

  Future<bool> uninstallApp(String deviceId, String packageName) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'uninstall', packageName]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> forceStopApp(String deviceId, String packageName) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'shell', 'am', 'force-stop', packageName]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleUiMode(String deviceId, bool darkMode) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final mode = darkMode ? 'yes' : 'no';
      final result = await Process.run(adbExe, ['-s', deviceId, 'shell', 'cmd', 'uimode', 'night', mode]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendKeyEvent(String deviceId, int keyCode) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'shell', 'input', 'keyevent', keyCode.toString()]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> captureScreenshot(String deviceId) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return null;

    try {
      final picturesDir = Platform.environment['USERPROFILE'] != null
          ? p.join(Platform.environment['USERPROFILE']!, 'Pictures')
          : Directory.current.path;
      final fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final targetPath = p.join(picturesDir, fileName);

      final process = await Process.start(adbExe, ['-s', deviceId, 'exec-out', 'screencap', '-p']);
      final file = File(targetPath);
      final sink = file.openWrite();
      await process.stdout.pipe(sink);
      final exitCode = await process.exitCode;

      if (exitCode == 0 && await file.exists()) {
        return targetPath;
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> listThirdPartyPackages(String deviceId) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return [];

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'shell', 'pm', 'list', 'packages', '-3']);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout as String);
        return lines
            .where((l) => l.startsWith('package:'))
            .map((l) => l.substring('package:'.length).trim())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String?> detectPackageName(String projectPath) async {
    try {
      // 1. Check android/app/build.gradle
      final gradleFile = File(p.join(projectPath, 'android', 'app', 'build.gradle'));
      if (await gradleFile.exists()) {
        final content = await gradleFile.readAsString();
        // Look for applicationId "com.example.app" or namespace "com.example.app"
        final match = RegExp(r'(?:applicationId|namespace)\s+[="]+([a-zA-Z0-9_.]+)["=]').firstMatch(content);
        if (match != null) {
          return match.group(1);
        }
      }

      // 2. Check android/app/build.gradle.kts
      final ktsFile = File(p.join(projectPath, 'android', 'app', 'build.gradle.kts'));
      if (await ktsFile.exists()) {
        final content = await ktsFile.readAsString();
        final match = RegExp(r'(?:applicationId|namespace)\s*=\s*"([a-zA-Z0-9_.]+)"').firstMatch(content);
        if (match != null) {
          return match.group(1);
        }
      }

      // 3. Fallback: AndroidManifest.xml
      final manifestFile = File(p.join(projectPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'));
      if (await manifestFile.exists()) {
        final content = await manifestFile.readAsString();
        final match = RegExp(r'package="([a-zA-Z0-9_.]+)"').firstMatch(content);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String> fixGradleLocks(String projectPath) async {
    final report = <String>[];
    try {
      // 1. Stop Gradle daemons via gradlew.bat --stop
      final gradlew = File(p.join(projectPath, 'android', 'gradlew.bat'));
      if (await gradlew.exists()) {
        try {
          final res = await Process.run(
            gradlew.path,
            ['--stop'],
            workingDirectory: p.join(projectPath, 'android'),
            runInShell: true,
          );
          if (res.exitCode == 0) {
            report.add('Stopped Gradle daemons.');
          }
        } catch (_) {}
      }

      // 2. Delete locked build/app/intermediates
      final intermediates = Directory(p.join(projectPath, 'build', 'app', 'intermediates'));
      if (await intermediates.exists()) {
        try {
          await intermediates.delete(recursive: true);
          report.add('Cleaned locked intermediates.');
        } catch (e) {
          report.add('Intermediates reset note: $e');
        }
      }

      // 3. Run flutter clean
      final flutterExe = _sdkService.flutterExe;
      if (flutterExe != null) {
        try {
          final cleanRes = await Process.run(
            flutterExe,
            ['clean'],
            workingDirectory: projectPath,
            runInShell: true,
          );
          if (cleanRes.exitCode == 0) {
            report.add('Ran flutter clean.');
          }
        } catch (_) {}
      }

      return report.isEmpty ? 'Cleaned build locks.' : report.join(' ');
    } catch (e) {
      return 'Error cleaning locks: $e';
    }
  }

  Future<bool> installApk(String deviceId, String apkPath) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'install', '-r', apkPath]);
      return result.exitCode == 0 && (result.stdout as String).contains('Success');
    } catch (_) {
      return false;
    }
  }

  Future<bool> launchDeepLink(String deviceId, String url) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, [
        '-s',
        deviceId,
        'shell',
        'am',
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-d',
        url,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendClipboardText(String deviceId, String text) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final escaped = text
          .replaceAll(' ', '%s')
          .replaceAll('&', '\\&')
          .replaceAll('"', '\\"')
          .replaceAll("'", "\\'");
      final result = await Process.run(adbExe, [
        '-s',
        deviceId,
        'shell',
        'input',
        'text',
        escaped,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
