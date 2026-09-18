import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
      // Start as detached process so it keeps running independently
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
