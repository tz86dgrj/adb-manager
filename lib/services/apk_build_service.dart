import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/apk_build_options.dart';
import 'sdk_service.dart';

class ApkBuildService {
  final SdkService _sdkService;

  bool _isBuilding = false;
  bool get isBuilding => _isBuilding;

  Process? _activeProcess;
  final _outputController = StreamController<String>.broadcast();
  Stream<String> get outputStream => _outputController.stream;

  ApkBuildService(this._sdkService);

  List<String> getCliArgs(ApkBuildOptions options) {
    final args = <String>[
      'build',
      options.target == ApkBuildTarget.apk ? 'apk' : 'appbundle',
    ];

    switch (options.mode) {
      case ApkBuildMode.debug:
        args.add('--debug');
        break;
      case ApkBuildMode.profile:
        args.add('--profile');
        break;
      case ApkBuildMode.release:
        args.add('--release');
        break;
    }

    if (options.splitPerAbi && options.target == ApkBuildTarget.apk) {
      args.add('--split-per-abi');
    }

    if (options.dartDefineFromFile != null && options.dartDefineFromFile!.trim().isNotEmpty) {
      args.add('--dart-define-from-file=${options.dartDefineFromFile!.trim()}');
    }

    if (options.flavor != null && options.flavor!.trim().isNotEmpty) {
      args.add('--flavor=${options.flavor!.trim()}');
    }

    if (options.entrypoint != null &&
        options.entrypoint!.trim().isNotEmpty &&
        options.entrypoint!.trim() != 'lib/main.dart') {
      args.add('-t');
      args.add(options.entrypoint!.trim());
    }

    if (options.additionalArgs != null && options.additionalArgs!.trim().isNotEmpty) {
      final extra = options.additionalArgs!.trim().split(RegExp(r'\s+'));
      args.addAll(extra);
    }

    return args;
  }

  String getCommandPreview(ApkBuildOptions options) {
    final exe = _sdkService.flutterExe ?? 'flutter';
    return '$exe ${getCliArgs(options).join(' ')}';
  }

  Future<ApkBuildResult> startBuild({
    required String projectPath,
    required ApkBuildOptions options,
  }) async {
    if (_isBuilding) {
      return const ApkBuildResult(
        success: false,
        errorMessage: 'A build is already in progress.',
      );
    }

    final flutterExe = _sdkService.flutterExe;
    if (flutterExe == null) {
      return const ApkBuildResult(
        success: false,
        errorMessage: 'Flutter executable not found in PATH or Android SDK.',
      );
    }

    _isBuilding = true;
    final startTime = DateTime.now();
    final args = getCliArgs(options);
    final logBuffer = <String>[];

    _outputController.add('🚀 Starting build: flutter ${args.join(" ")}\n');

    try {
      _activeProcess = await Process.start(
        flutterExe,
        args,
        workingDirectory: projectPath,
        runInShell: true,
      );

      _activeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        logBuffer.add(line);
        _outputController.add(line);
      });

      _activeProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        logBuffer.add(line);
        _outputController.add('[ERROR] $line');
      });

      final exitCode = await _activeProcess!.exitCode;
      final duration = DateTime.now().difference(startTime);
      _isBuilding = false;
      _activeProcess = null;

      if (exitCode == 0) {
        final outputs = await _locateOutputs(projectPath, options);
        final primary = outputs.isNotEmpty ? outputs.first : null;
        int? size;
        if (primary != null) {
          final file = File(primary);
          if (await file.exists()) {
            size = await file.length();
          }
        }

        return ApkBuildResult(
          success: true,
          primaryOutputFile: primary,
          allOutputFiles: outputs,
          fileSizeBytes: size,
          duration: duration,
          logs: logBuffer,
        );
      } else {
        return ApkBuildResult(
          success: false,
          duration: duration,
          errorMessage: 'Flutter build process exited with code $exitCode',
          logs: logBuffer,
        );
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _isBuilding = false;
      _activeProcess = null;
      return ApkBuildResult(
        success: false,
        duration: duration,
        errorMessage: 'Exception during build: $e',
        logs: logBuffer,
      );
    }
  }

  Future<void> cancelBuild() async {
    if (_activeProcess != null) {
      _outputController.add('🛑 Build cancellation requested by user...');
      _activeProcess!.kill(ProcessSignal.sigkill);
      _activeProcess = null;
      _isBuilding = false;
    }
  }

  Future<List<String>> _locateOutputs(String projectPath, ApkBuildOptions options) async {
    final results = <String>[];
    String outputDir;

    if (options.target == ApkBuildTarget.apk) {
      outputDir = p.join(projectPath, 'build', 'app', 'outputs', 'flutter-apk');
    } else {
      final flavorPart = options.flavor != null ? '${options.flavor}Release' : 'release';
      outputDir = p.join(projectPath, 'build', 'app', 'outputs', 'bundle', flavorPart);
    }

    final dir = Directory(outputDir);
    if (await dir.exists()) {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.apk' || ext == '.aab') {
            // Avoid picking intermediate sha1/sha256 files if any
            results.add(entity.path);
          }
        }
      }
    }

    // Sort to place preferred release/debug artifact first
    results.sort((a, b) {
      final aName = p.basename(a).toLowerCase();
      final bName = p.basename(b).toLowerCase();
      if (aName.contains('release') && !bName.contains('release')) return -1;
      if (!aName.contains('release') && bName.contains('release')) return 1;
      return aName.compareTo(bName);
    });

    return results;
  }
}
