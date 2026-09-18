import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:adb_manager/models/adb_device.dart';
import 'package:adb_manager/models/apk_build_options.dart';
import 'package:adb_manager/models/avd_creation_options.dart';
import 'package:adb_manager/models/avd_info.dart';
import 'package:adb_manager/models/device_session.dart';
import 'package:adb_manager/models/launch_config.dart';
import 'package:adb_manager/models/log_entry.dart';
import 'package:adb_manager/services/agent_bridge_service.dart';
import 'package:adb_manager/services/apk_build_service.dart';
import 'package:adb_manager/services/avd_service.dart';
import 'package:adb_manager/services/sdk_service.dart';

void main() {
  group('Model Tests', () {
    test('AvdInfo model properties', () {
      final avd = AvdInfo(
        id: 'Pixel_7_Pro',
        name: 'Pixel 7 Pro',
        isRunning: true,
        runningDeviceId: 'emulator-5554',
      );

      expect(avd.id, 'Pixel_7_Pro');
      expect(avd.name, 'Pixel 7 Pro');
      expect(avd.isRunning, true);
      expect(avd.runningDeviceId, 'emulator-5554');
    });

    test('AdbDevice model displayName and isReady', () {
      final dev = AdbDevice(
        id: 'emulator-5554',
        state: 'device',
        model: 'sdk_gphone16k_x86_64',
        isEmulator: true,
      );

      expect(dev.isReady, true);
      expect(dev.displayName, 'sdk gphone16k x86 64');
    });

    test('LogEntry formatting and deviceId tagging', () {
      final entry = LogEntry(
        message: 'Hot Reload performed in 250ms',
        level: LogLevel.success,
        source: 'flutter',
        deviceId: 'emulator-5554',
      );

      expect(entry.level, LogLevel.success);
      expect(entry.message, contains('Hot Reload'));
      expect(entry.deviceId, 'emulator-5554');
      expect(entry.toString(), contains('[emulator-5554]'));
    });

    test('DeviceSession per-device log isolation', () {
      final sessionA = DeviceSession(deviceId: 'emulator-5554');
      final sessionB = DeviceSession(deviceId: 'emulator-5556');

      sessionA.addLog(LogEntry(message: 'App started on 5554', deviceId: 'emulator-5554'));
      expect(sessionA.logs.length, 1);
      expect(sessionB.logs.isEmpty, isTrue);

      sessionB.addLog(LogEntry(message: 'App started on 5556', deviceId: 'emulator-5556'));
      expect(sessionA.logs.length, 1);
      expect(sessionB.logs.length, 1);
      expect(sessionA.logs.first.message, 'App started on 5554');
      expect(sessionB.logs.first.message, 'App started on 5556');

      sessionA.clearLogs();
      expect(sessionA.logs.isEmpty, isTrue);
      expect(sessionB.logs.length, 1);
    });

    test('LaunchConfig serialization and dart-define-from-file support', () {
      const cfg = LaunchConfig(
        dartDefineFromFile: 'dart_defines.json',
        flavor: 'dev',
        target: 'lib/main_dev.dart',
        mode: 'debug',
        additionalArgs: '--no-sound-null-safety',
      );

      final jsonStr = cfg.toJson();
      final restored = LaunchConfig.fromJson(jsonStr);

      expect(restored.dartDefineFromFile, 'dart_defines.json');
      expect(restored.flavor, 'dev');
      expect(restored.target, 'lib/main_dev.dart');
      expect(restored.mode, 'debug');
      expect(restored.additionalArgs, '--no-sound-null-safety');
    });

    test('DeviceSession state and log buffering', () {
      final session = DeviceSession(deviceId: 'emulator-5554');
      expect(session.isRunning, isFalse);
      expect(session.isStarting, isFalse);

      session.state = SessionRunState.building;
      expect(session.isStarting, isTrue);

      session.state = SessionRunState.running;
      expect(session.isRunning, isTrue);
      expect(session.canReload, isTrue);

      session.state = SessionRunState.reloading;
      expect(session.isRunning, isTrue);

      session.addLog(LogEntry(message: 'Hot reload completed'));
      expect(session.logs.length, 1);
      expect(session.logs.first.message, 'Hot reload completed');

      session.clearLogs();
      expect(session.logs.isEmpty, isTrue);
    });

    test('ApkBuildOptions and ApkBuildResult properties', () {
      const options = ApkBuildOptions(
        target: ApkBuildTarget.apk,
        mode: ApkBuildMode.release,
        splitPerAbi: true,
        dartDefineFromFile: 'dart_defines.prod.json',
        flavor: 'prod',
      );

      expect(options.target, ApkBuildTarget.apk);
      expect(options.mode, ApkBuildMode.release);
      expect(options.splitPerAbi, isTrue);
      expect(options.dartDefineFromFile, 'dart_defines.prod.json');
      expect(options.flavor, 'prod');

      const result = ApkBuildResult(
        success: true,
        primaryOutputFile: 'C:/app/build/outputs/app-release.apk',
        fileSizeBytes: 25 * 1024 * 1024,
      );

      expect(result.success, isTrue);
      expect(result.formattedFileSize, '25.00 MB');
    });

    test('DeviceProfile, SystemImageInfo and AvdCreationResult properties', () {
      const profile = DeviceProfile(id: 'pixel_7', name: 'Pixel 7', oem: 'Google');
      expect(profile.id, 'pixel_7');
      expect(profile.name, 'Pixel 7');
      expect(DeviceProfile.defaults, isNotEmpty);

      const sysImg = SystemImageInfo(
        packagePath: 'system-images;android-34;google_apis;x86_64',
        displayName: 'Android 34 (Google APIs - x86_64)',
        apiLevel: '34',
        abi: 'x86_64',
        tag: 'google_apis',
      );
      expect(sysImg.apiLevel, '34');
      expect(sysImg.abi, 'x86_64');

      const res = AvdCreationResult(success: true, message: 'Created', avdName: 'Test_AVD');
      expect(res.success, isTrue);
      expect(res.avdName, 'Test_AVD');
    });

    test('ApkBuildService getCliArgs constructs correct flutter build commands', () {
      final sdkService = SdkService();
      final builder = ApkBuildService(sdkService);

      // 1. Release APK with defines and ABI split
      const releaseOptions = ApkBuildOptions(
        target: ApkBuildTarget.apk,
        mode: ApkBuildMode.release,
        splitPerAbi: true,
        dartDefineFromFile: 'dart_defines.json',
        flavor: 'prod',
        entrypoint: 'lib/main_prod.dart',
      );

      final releaseArgs = builder.getCliArgs(releaseOptions);
      expect(releaseArgs, [
        'build',
        'apk',
        '--release',
        '--split-per-abi',
        '--dart-define-from-file=dart_defines.json',
        '--flavor=prod',
        '-t',
        'lib/main_prod.dart',
      ]);

      // 2. Debug AppBundle
      const debugBundleOptions = ApkBuildOptions(
        target: ApkBuildTarget.appbundle,
        mode: ApkBuildMode.debug,
      );

      final bundleArgs = builder.getCliArgs(debugBundleOptions);
      expect(bundleArgs, [
        'build',
        'appbundle',
        '--debug',
      ]);
    });
  });

  group('SdkService Detection', () {
    test('Detects local Android SDK and Flutter', () async {
      final sdkService = SdkService();
      await sdkService.initialize();

      expect(sdkService.sdkPath, isNotNull);
      expect(sdkService.adbExe, isNotNull);
      expect(sdkService.emulatorExe, isNotNull);
      expect(sdkService.flutterExe, isNotNull);
      expect(sdkService.isReady, isTrue);
    });
  });

  group('AvdService Tests', () {
    test('Scans installed system images and device profiles', () async {
      final sdkService = SdkService();
      await sdkService.initialize();
      final avdService = AvdService(sdkService);

      final profiles = await avdService.listDeviceProfiles();
      expect(profiles, isNotEmpty);

      final images = await avdService.listInstalledSystemImages();
      expect(images, isNotEmpty);
      expect(images.first.packagePath, contains('system-images;'));
    });
  });

  group('AgentBridgeService Tests', () {
    test('Starts on loopback, responds to status, reload, and shuts down cleanly', () async {
      bool reloadCalled = false;
      final bridge = AgentBridgeService(
        onReload: ({String? deviceId, bool all = false}) async {
          reloadCalled = true;
          return true;
        },
        onStatus: () => {'testStatus': 'ok'},
      );

      final started = await bridge.start(port: 48999);
      expect(started, isTrue);
      expect(bridge.isRunning, isTrue);
      expect(bridge.port, isNotNull);

      final client = HttpClient();
      final statusReq = await client.getUrl(Uri.parse('http://127.0.0.1:${bridge.port}/api/status'));
      final statusRes = await statusReq.close();
      expect(statusRes.statusCode, 200);

      final statusBody = await utf8.decoder.bind(statusRes).join();
      final statusJson = jsonDecode(statusBody) as Map<String, dynamic>;
      expect(statusJson['bridge'], 'online');
      expect(statusJson['testStatus'], 'ok');

      final reloadReq = await client.postUrl(Uri.parse('http://127.0.0.1:${bridge.port}/api/reload'));
      reloadReq.headers.contentType = ContentType.json;
      reloadReq.write(jsonEncode({'deviceId': 'emulator-5554'}));
      final reloadRes = await reloadReq.close();
      expect(reloadRes.statusCode, 200);
      expect(reloadCalled, isTrue);

      client.close();
      await bridge.stop();
      expect(bridge.isRunning, isFalse);
    });
  });
}
