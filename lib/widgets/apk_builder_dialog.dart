import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/apk_build_options.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ApkBuilderDialog extends StatefulWidget {
  final AppState state;

  const ApkBuilderDialog({super.key, required this.state});

  @override
  State<ApkBuilderDialog> createState() => _ApkBuilderDialogState();
}

enum _DialogStep { configure, building, completed }

class _ApkBuilderDialogState extends State<ApkBuilderDialog> {
  _DialogStep _step = _DialogStep.configure;

  late ApkBuildTarget _target;
  late ApkBuildMode _mode;
  bool _splitPerAbi = false;
  late TextEditingController _definesController;
  late TextEditingController _flavorController;
  late TextEditingController _targetController;
  late TextEditingController _additionalArgsController;

  final ScrollController _logScrollController = ScrollController();
  final List<String> _buildLogs = [];
  StreamSubscription<String>? _logSub;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  ApkBuildResult? _buildResult;
  bool _isInstalling = false;
  String? _installStatus;

  @override
  void initState() {
    super.initState();
    final cfg = widget.state.launchConfig;
    _target = ApkBuildTarget.apk;
    _mode = ApkBuildMode.release;
    _splitPerAbi = false;
    _definesController = TextEditingController(text: cfg.dartDefineFromFile ?? '');
    _flavorController = TextEditingController(text: cfg.flavor ?? '');
    _targetController = TextEditingController(text: cfg.target);
    _additionalArgsController = TextEditingController(text: cfg.additionalArgs ?? '');

    _definesController.addListener(() => setState(() {}));
    _flavorController.addListener(() => setState(() {}));
    _targetController.addListener(() => setState(() {}));
    _additionalArgsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _elapsedTimer?.cancel();
    _definesController.dispose();
    _flavorController.dispose();
    _targetController.dispose();
    _additionalArgsController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  ApkBuildOptions _getCurrentOptions() {
    return ApkBuildOptions(
      target: _target,
      mode: _mode,
      splitPerAbi: _splitPerAbi,
      dartDefineFromFile: _definesController.text.trim().isNotEmpty ? _definesController.text.trim() : null,
      flavor: _flavorController.text.trim().isNotEmpty ? _flavorController.text.trim() : null,
      entrypoint: _targetController.text.trim().isNotEmpty ? _targetController.text.trim() : null,
      additionalArgs: _additionalArgsController.text.trim().isNotEmpty ? _additionalArgsController.text.trim() : null,
    );
  }

  Future<void> _pickDefinesFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select Dart Defines JSON file',
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: widget.state.currentProjectPath,
    );

    if (result.isNotEmpty && result.first.path != null) {
      final fullPath = result.first.path!;
      final projectPath = widget.state.currentProjectPath;
      if (projectPath != null && fullPath.startsWith(projectPath)) {
        final rel = p.relative(fullPath, from: projectPath);
        _definesController.text = rel;
      } else {
        _definesController.text = fullPath;
      }
    }
  }

  Future<void> _startBuild() async {
    setState(() {
      _step = _DialogStep.building;
      _buildLogs.clear();
      _elapsedSeconds = 0;
      _buildResult = null;
      _installStatus = null;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    _logSub = widget.state.apkBuildService.outputStream.listen((line) {
      if (mounted) {
        setState(() {
          _buildLogs.add(line);
        });
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent + 40,
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOut,
          );
        }
      }
    });

    final options = _getCurrentOptions();
    final result = await widget.state.buildApk(options);

    _elapsedTimer?.cancel();
    _logSub?.cancel();

    if (mounted) {
      setState(() {
        _buildResult = result;
        _step = _DialogStep.completed;
      });
    }
  }

  Future<void> _cancelBuild() async {
    await widget.state.cancelApkBuild();
    _elapsedTimer?.cancel();
    _logSub?.cancel();
    if (mounted) {
      setState(() {
        _step = _DialogStep.configure;
      });
    }
  }

  Future<void> _installToActiveDevice(String apkPath) async {
    final dev = widget.state.selectedDeviceId;
    if (dev == null) {
      setState(() => _installStatus = 'No active device selected to install to.');
      return;
    }

    setState(() {
      _isInstalling = true;
      _installStatus = 'Installing APK to $dev...';
    });

    final ok = await widget.state.installApkToActiveDevice(apkPath, targetDeviceId: dev);

    if (mounted) {
      setState(() {
        _isInstalling = false;
        _installStatus = ok
            ? '✅ Successfully installed on $dev!'
            : '❌ Installation failed. Check device logs.';
      });
    }
  }

  void _openInExplorer(String filePath) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else {
      final dir = p.dirname(filePath);
      Process.run('open', [dir]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Container(
        width: 760,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            _buildHeader(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Dynamic Step Body
            Expanded(
              child: switch (_step) {
                _DialogStep.configure => _buildConfigureBody(),
                _DialogStep.building => _buildBuildingBody(),
                _DialogStep.completed => _buildCompletedBody(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primarySubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'APK & AppBundle Builder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                widget.state.currentProjectPath != null
                    ? p.basename(widget.state.currentProjectPath!)
                    : 'No project selected',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (_step == _DialogStep.configure)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  Widget _buildConfigureBody() {
    final preview = widget.state.apkBuildService.getCommandPreview(_getCurrentOptions());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target & Mode selectors
          Row(
            children: [
              // Target: APK vs AppBundle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Build Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SegmentedButton<ApkBuildTarget>(
                      segments: const [
                        ButtonSegment(
                          value: ApkBuildTarget.apk,
                          label: Text('APK (.apk)'),
                          icon: Icon(Icons.android_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ApkBuildTarget.appbundle,
                          label: Text('App Bundle (.aab)'),
                          icon: Icon(Icons.archive_rounded, size: 16),
                        ),
                      ],
                      selected: {_target},
                      onSelectionChanged: (set) => setState(() => _target = set.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Mode: Debug vs Profile vs Release
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Build Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SegmentedButton<ApkBuildMode>(
                      segments: const [
                        ButtonSegment(value: ApkBuildMode.debug, label: Text('Debug')),
                        ButtonSegment(value: ApkBuildMode.profile, label: Text('Profile')),
                        ButtonSegment(value: ApkBuildMode.release, label: Text('Release')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (set) => setState(() => _mode = set.first),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Options Row (ABI Splitting)
          if (_target == ApkBuildTarget.apk)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: _splitPerAbi,
              title: const Text(
                'Split per ABI (--split-per-abi)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Generates smaller, separate APKs for arm64-v8a, armeabi-v7a, and x86_64',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              onChanged: (v) => setState(() => _splitPerAbi = v ?? false),
            ),

          const SizedBox(height: 12),

          // Dart Define From File
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dart Defines File (--dart-define-from-file)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _definesController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'e.g. dart_defines.json or config/prod.json',
                        isDense: true,
                        prefixIcon: Icon(Icons.code_rounded, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickDefinesFile,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Browse...'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Flavor & Target entrypoint
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Flavor (--flavor)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _flavorController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'e.g. dev, staging, prod (optional)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Entrypoint (-t)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _targetController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'lib/main.dart',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Additional Flags
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Additional Flags (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _additionalArgsController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g. --no-tree-shake-icons --obfuscate',
                  isDense: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Command Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal_rounded, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'COMMAND PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  preview,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: widget.state.currentProjectPath != null ? _startBuild : null,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(
                  'Build ${_target == ApkBuildTarget.apk ? "APK" : "Bundle"} (${_mode.name.toUpperCase()})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Building Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compiling ${_target == ApkBuildTarget.apk ? "APK" : "AppBundle"} in ${_mode.name.toUpperCase()} mode...',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Running Gradle tasks. This may take 1-2 minutes on first build.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${_elapsedSeconds}s',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Consolas',
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _cancelBuild,
                icon: const Icon(Icons.cancel_rounded, size: 16, color: AppTheme.error),
                label: const Text('Cancel Build', style: TextStyle(color: AppTheme.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Live Log Output
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.consoleBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.consoleBorder),
            ),
            child: ListView.builder(
              controller: _logScrollController,
              itemCount: _buildLogs.length,
              itemBuilder: (context, index) {
                final line = _buildLogs[index];
                final isError = line.startsWith('[ERROR]') || line.contains('FAILURE:');
                return SelectableText(
                  line,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    height: 1.35,
                    color: isError ? AppTheme.error : AppTheme.consoleText,
                    fontWeight: isError ? FontWeight.w700 : FontWeight.w400,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedBody() {
    final res = _buildResult;
    final isSuccess = res?.success ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Outcome Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSuccess ? AppTheme.successSubtle : AppTheme.errorSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (isSuccess ? AppTheme.success : AppTheme.error).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isSuccess ? AppTheme.success : AppTheme.error,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess
                          ? 'Build Succeeded in ${res?.duration.inSeconds ?? 0} seconds!'
                          : 'Build Failed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSuccess ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSuccess
                          ? 'Artifact generated ready for installation or deployment.'
                          : (res?.errorMessage ?? 'Compilation failed. See logs below.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSuccess ? AppTheme.textSecondary : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (isSuccess && res?.primaryOutputFile != null) ...[
          // Primary Artifact Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.basename(res!.primaryOutputFile!),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        res.formattedFileSize,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  res.primaryOutputFile!,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    // Install on Device
                    FilledButton.icon(
                      onPressed: !_isInstalling
                          ? () => _installToActiveDevice(res.primaryOutputFile!)
                          : null,
                      icon: _isInstalling
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.install_mobile_rounded, size: 18),
                      label: Text(
                        widget.state.selectedDeviceId != null
                            ? 'Install on ${widget.state.selectedDeviceId}'
                            : 'Install on Device',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
                    ),

                    const SizedBox(width: 10),

                    // Open in Explorer
                    OutlinedButton.icon(
                      onPressed: () => _openInExplorer(res.primaryOutputFile!),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Open in Explorer'),
                    ),

                    const SizedBox(width: 10),

                    // Copy Path
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy full APK path',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: res.primaryOutputFile!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('APK path copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),

                if (_installStatus != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _installStatus!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _installStatus!.contains('✅') ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),
        ],

        // Build Logs Accordion
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.consoleBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.consoleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPILATION LOGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _buildLogs.length,
                    itemBuilder: (context, index) {
                      final line = _buildLogs[index];
                      final isError = line.startsWith('[ERROR]') || line.contains('FAILURE:');
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 10.5,
                          color: isError ? AppTheme.error : AppTheme.consoleText,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Bottom Dialog Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _step = _DialogStep.configure),
              child: const Text('Back to Config'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }
}
