import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/avd_creation_options.dart';
import '../models/avd_info.dart';
import 'sdk_service.dart';

class AvdService {
  final SdkService _sdkService;

  AvdService(this._sdkService);

  Future<List<AvdInfo>> listAvds() async {
    final emulatorExe = _sdkService.emulatorExe;
    if (emulatorExe == null) return [];

    try {
      final result = await Process.run(emulatorExe, ['-list-avds']);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout as String);
        final avds = <AvdInfo>[];
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            avds.add(AvdInfo(
              id: trimmed,
              name: trimmed.replaceAll('_', ' '),
            ));
          }
        }
        return avds;
      }
    } catch (_) {}
    return [];
  }

  Future<List<SystemImageInfo>> listInstalledSystemImages() async {
    final sdkPath = _sdkService.sdkPath;
    if (sdkPath == null) return [];

    final images = <SystemImageInfo>[];
    final sysImagesDir = Directory(p.join(sdkPath, 'system-images'));
    if (!await sysImagesDir.exists()) return [];

    try {
      // Structure: system-images/<api-dir>/<tag-dir>/<abi-dir>
      await for (final apiEntity in sysImagesDir.list()) {
        if (apiEntity is! Directory) continue;
        final apiDirName = p.basename(apiEntity.path);

        await for (final tagEntity in apiEntity.list()) {
          if (tagEntity is! Directory) continue;
          final tagDirName = p.basename(tagEntity.path);

          await for (final abiEntity in tagEntity.list()) {
            if (abiEntity is! Directory) continue;
            final abiDirName = p.basename(abiEntity.path);

            final propsFile = File(p.join(abiEntity.path, 'source.properties'));
            String apiLevel = apiDirName.replaceFirst('android-', '');
            String tagDisplay = tagDirName.replaceAll('_', ' ');
            String abi = abiDirName;

            if (await propsFile.exists()) {
              final lines = await propsFile.readAsLines();
              for (final line in lines) {
                if (line.startsWith('AndroidVersion.ApiLevel=')) {
                  apiLevel = line.split('=')[1].trim();
                } else if (line.startsWith('SystemImage.TagDisplay=')) {
                  tagDisplay = line.split('=')[1].trim();
                } else if (line.startsWith('SystemImage.Abi=')) {
                  abi = line.split('=')[1].trim();
                }
              }
            }

            final packagePath = 'system-images;$apiDirName;$tagDirName;$abiDirName';
            final displayName = 'Android $apiLevel ($tagDisplay - $abi)';

            images.add(SystemImageInfo(
              packagePath: packagePath,
              displayName: displayName,
              apiLevel: apiLevel,
              abi: abi,
              tag: tagDirName,
            ));
          }
        }
      }
    } catch (_) {}

    // Sort descending by API level
    images.sort((a, b) => (double.tryParse(b.apiLevel) ?? 0).compareTo(double.tryParse(a.apiLevel) ?? 0));
    return images;
  }

  Future<List<DeviceProfile>> listDeviceProfiles() async {
    final avdManagerExe = _sdkService.avdManagerExe;
    if (avdManagerExe == null) return DeviceProfile.defaults;

    final env = Map<String, String>.from(Platform.environment);
    if (_sdkService.javaHome != null) {
      env['JAVA_HOME'] = _sdkService.javaHome!;
    }

    try {
      final res = await Process.run(
        avdManagerExe,
        ['list', 'device'],
        environment: env,
        runInShell: true,
      );

      if (res.exitCode == 0) {
        final parsed = _parseDeviceList(res.stdout as String);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    return DeviceProfile.defaults;
  }

  List<DeviceProfile> _parseDeviceList(String output) {
    final list = <DeviceProfile>[];
    final lines = LineSplitter.split(output);
    String? currentId;
    String? currentName;
    String? currentOem;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('id:')) {
        final match = RegExp(r'"([^"]+)"').firstMatch(trimmed);
        if (match != null) {
          currentId = match.group(1);
        }
      } else if (trimmed.startsWith('Name:')) {
        currentName = trimmed.replaceFirst('Name:', '').trim();
      } else if (trimmed.startsWith('OEM :')) {
        currentOem = trimmed.replaceFirst('OEM :', '').trim();
      } else if (trimmed.startsWith('---------') || trimmed.isEmpty) {
        if (currentId != null && currentName != null) {
          list.add(DeviceProfile(
            id: currentId,
            name: currentName,
            oem: currentOem ?? 'Google',
          ));
        }
        currentId = null;
        currentName = null;
        currentOem = null;
      }
    }
    if (currentId != null && currentName != null) {
      list.add(DeviceProfile(
        id: currentId,
        name: currentName,
        oem: currentOem ?? 'Google',
      ));
    }

    return list.isNotEmpty ? list : DeviceProfile.defaults;
  }

  Future<AvdCreationResult> createAvd({
    required String name,
    required String deviceProfileId,
    required String systemImagePackage,
    int ramMb = 2048,
    int internalStorageMb = 6144,
  }) async {
    final avdManagerExe = _sdkService.avdManagerExe;
    if (avdManagerExe == null) {
      return const AvdCreationResult(
        success: false,
        message: 'avdmanager CLI not found in Android SDK cmdline-tools.',
      );
    }

    final env = Map<String, String>.from(Platform.environment);
    if (_sdkService.javaHome != null) {
      env['JAVA_HOME'] = _sdkService.javaHome!;
    }

    try {
      final process = await Process.start(
        avdManagerExe,
        [
          'create',
          'avd',
          '-n',
          name,
          '-k',
          systemImagePackage,
          '-d',
          deviceProfileId,
          '--force',
        ],
        environment: env,
        runInShell: true,
      );

      process.stdin.writeln('no');
      await process.stdin.flush();
      await process.stdin.close();

      final out = await process.stdout.transform(utf8.decoder).join();
      final err = await process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        await _tuneAvdConfig(name, ramMb: ramMb, internalStorageMb: internalStorageMb);
        return AvdCreationResult(
          success: true,
          message: 'AVD "$name" created successfully!',
          avdName: name,
        );
      } else {
        final msg = err.trim().isNotEmpty ? err : out;
        return AvdCreationResult(
          success: false,
          message: 'Failed to create AVD: $msg',
        );
      }
    } catch (e) {
      return AvdCreationResult(
        success: false,
        message: 'Error executing avdmanager: $e',
      );
    }
  }

  Future<void> _tuneAvdConfig(
    String avdName, {
    required int ramMb,
    required int internalStorageMb,
  }) async {
    try {
      final homeDir = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (homeDir == null) return;

      final configPath = p.join(homeDir, '.android', 'avd', '$avdName.avd', 'config.ini');
      final configFile = File(configPath);
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        var updated = content;

        if (updated.contains('hw.ramSize=')) {
          updated = updated.replaceAll(RegExp(r'hw\.ramSize=\d+'), 'hw.ramSize=$ramMb');
        } else {
          updated += '\nhw.ramSize=$ramMb';
        }

        if (updated.contains('disk.dataPartition.size=')) {
          updated = updated.replaceAll(RegExp(r'disk\.dataPartition\.size=.*'), 'disk.dataPartition.size=${internalStorageMb}M');
        } else {
          updated += '\ndisk.dataPartition.size=${internalStorageMb}M';
        }

        await configFile.writeAsString(updated);
      }
    } catch (_) {}
  }

  Future<bool> deleteAvd(String avdName) async {
    final avdManagerExe = _sdkService.avdManagerExe;
    if (avdManagerExe == null) return false;

    final env = Map<String, String>.from(Platform.environment);
    if (_sdkService.javaHome != null) {
      env['JAVA_HOME'] = _sdkService.javaHome!;
    }

    try {
      final result = await Process.run(
        avdManagerExe,
        ['delete', 'avd', '-n', avdName],
        environment: env,
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> launchAvd(
    String avdName, {
    bool coldBoot = false,
    bool wipeData = false,
  }) async {
    final emulatorExe = _sdkService.emulatorExe;
    if (emulatorExe == null) return false;

    final args = <String>[
      '-avd',
      avdName,
      '-netdelay',
      'none',
      '-netspeed',
      'full',
    ];

    if (coldBoot) {
      args.add('-no-snapshot-load');
    }
    if (wipeData) {
      args.add('-wipe-data');
    }

    try {
      await Process.start(
        emulatorExe,
        args,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> killEmulator(String deviceId) async {
    final adbExe = _sdkService.adbExe;
    if (adbExe == null) return false;

    try {
      final result = await Process.run(adbExe, ['-s', deviceId, 'emu', 'kill']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
