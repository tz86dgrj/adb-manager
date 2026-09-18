import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class LaunchConfigBar extends StatefulWidget {
  final AppState state;

  const LaunchConfigBar({super.key, required this.state});

  @override
  State<LaunchConfigBar> createState() => _LaunchConfigBarState();
}

class _LaunchConfigBarState extends State<LaunchConfigBar> {
  late TextEditingController _definesController;
  late TextEditingController _targetController;
  late TextEditingController _flavorController;
  late TextEditingController _extraArgsController;
  String? _activePreset;

  @override
  void initState() {
    super.initState();
    final cfg = widget.state.launchConfig;
    _definesController = TextEditingController(text: cfg.dartDefineFromFile ?? '');
    _targetController = TextEditingController(text: cfg.target ?? 'lib/main.dart');
    _flavorController = TextEditingController(text: cfg.flavor ?? '');
    _extraArgsController = TextEditingController(text: cfg.additionalArgs ?? '');
  }

  @override
  void didUpdateWidget(covariant LaunchConfigBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cfg = widget.state.launchConfig;
    if (_definesController.text != (cfg.dartDefineFromFile ?? '')) {
      _definesController.text = cfg.dartDefineFromFile ?? '';
    }
    if (_targetController.text != (cfg.target ?? 'lib/main.dart')) {
      _targetController.text = cfg.target ?? 'lib/main.dart';
    }
    if (_flavorController.text != (cfg.flavor ?? '')) {
      _flavorController.text = cfg.flavor ?? '';
    }
    if (_extraArgsController.text != (cfg.additionalArgs ?? '')) {
      _extraArgsController.text = cfg.additionalArgs ?? '';
    }
  }

  @override
  void dispose() {
    _definesController.dispose();
    _targetController.dispose();
    _flavorController.dispose();
    _extraArgsController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    final cur = widget.state.launchConfig;
    final updated = cur.copyWith(
      dartDefineFromFile: _definesController.text.trim().isEmpty ? null : _definesController.text.trim(),
      target: _targetController.text.trim().isEmpty ? 'lib/main.dart' : _targetController.text.trim(),
      flavor: _flavorController.text.trim().isEmpty ? null : _flavorController.text.trim(),
      additionalArgs: _extraArgsController.text.trim().isEmpty ? null : _extraArgsController.text.trim(),
    );
    widget.state.updateLaunchConfig(updated);
  }

  Future<void> _pickDefinesFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select dart-defines JSON File',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isNotEmpty && result.first.path != null) {
      String picked = result.first.path!;
      final proj = widget.state.currentProjectPath;
      if (proj != null && picked.startsWith(proj)) {
        picked = p.relative(picked, from: proj);
      }
      _definesController.text = picked;
      _saveConfig();
    }
  }

  String _buildPreviewCommand() {
    final dev = widget.state.selectedDeviceId ?? '<device>';
    final parts = ['flutter run -d $dev'];

    final cfg = widget.state.launchConfig;
    if (cfg.dartDefineFromFile != null && cfg.dartDefineFromFile!.isNotEmpty) {
      parts.add('--dart-define-from-file=${cfg.dartDefineFromFile}');
    }
    if (cfg.flavor != null && cfg.flavor!.isNotEmpty) {
      parts.add('--flavor ${cfg.flavor}');
    }
    if (cfg.target != null && cfg.target!.isNotEmpty && cfg.target != 'lib/main.dart') {
      parts.add('-t ${cfg.target}');
    }
    if (cfg.mode != 'debug') {
      parts.add('--${cfg.mode}');
    }
    if (cfg.additionalArgs != null && cfg.additionalArgs!.isNotEmpty) {
      parts.add(cfg.additionalArgs!);
    }
    return parts.join(' ');
  }

  Future<void> _applyPreset(String preset) async {
    setState(() => _activePreset = preset);
    final proj = widget.state.currentProjectPath;
    if (proj != null) {
      final candidates = [
        'dart_defines.$preset.json',
        'dart-defines.$preset.json',
        'env.$preset.json',
        'config/$preset.json',
        'environments/$preset.json',
        '$preset.json',
        'dart_defines.json',
      ];

      for (final cand in candidates) {
        final file = File(p.join(proj, cand));
        if (await file.exists()) {
          _definesController.text = cand;
          break;
        }
      }
    }

    _flavorController.text = preset;
    _saveConfig();
  }

  Future<void> _autoDetectDefines() async {
    final proj = widget.state.currentProjectPath;
    if (proj == null) return;
    final candidates = [
      'dart_defines.json',
      'dart-defines.json',
      'env.json',
      'config/dart_defines.json',
      'environments/dart_defines.json',
    ];
    for (final cand in candidates) {
      final file = File(p.join(proj, cand));
      if (await file.exists()) {
        _definesController.text = cand;
        _saveConfig();
        break;
      }
    }
  }

  Widget _buildPresetChip(String name, IconData icon, bool isRunning) {
    final lower = name.toLowerCase();
    final isSelected = _activePreset == lower ||
        (_activePreset == null && widget.state.launchConfig.flavor?.toLowerCase() == lower);

    return ActionChip(
      avatar: Icon(icon, size: 12, color: isSelected ? Colors.white : AppTheme.primary),
      label: Text(name, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      backgroundColor: isSelected ? AppTheme.primary : AppTheme.surface,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary),
      side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: isRunning ? null : () => _applyPreset(lower),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.state.runnerService.isRunning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Environment Presets
          Row(
            children: [
              const Text(
                'Environment Presets:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              _buildPresetChip('Dev', Icons.eco_rounded, isRunning),
              const SizedBox(width: 6),
              _buildPresetChip('Staging', Icons.flash_on_rounded, isRunning),
              const SizedBox(width: 6),
              _buildPresetChip('Prod', Icons.rocket_launch_rounded, isRunning),
              const Spacer(),
              TextButton.icon(
                onPressed: !isRunning ? () => _autoDetectDefines() : null,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
                label: const Text('Auto-detect JSON', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Dart Defines File
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dart Defines File (--dart-define-from-file)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _definesController,
                        enabled: !isRunning,
                        onChanged: (_) => _saveConfig(),
                        style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                        decoration: InputDecoration(
                          hintText: 'e.g. dart_defines.json',
                          hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          prefixIcon: const Icon(Icons.data_object_rounded, size: 14, color: AppTheme.primary),
                          prefixIconConstraints: const BoxConstraints(minWidth: 28),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_definesController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 14),
                                  onPressed: isRunning
                                      ? null
                                      : () {
                                          _definesController.clear();
                                          _saveConfig();
                                        },
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              IconButton(
                                icon: const Icon(Icons.folder_open_rounded, size: 14),
                                onPressed: isRunning ? null : _pickDefinesFile,
                                tooltip: 'Browse JSON file',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Flavor
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flavor (--flavor)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _flavorController,
                        enabled: !isRunning,
                        onChanged: (_) => _saveConfig(),
                        style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                        decoration: const InputDecoration(
                          hintText: 'e.g. dev, prod',
                          hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          prefixIcon: Icon(Icons.label_outline_rounded, size: 14, color: AppTheme.textSecondary),
                          prefixIconConstraints: BoxConstraints(minWidth: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Target Entrypoint
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target (-t)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _targetController,
                        enabled: !isRunning,
                        onChanged: (_) => _saveConfig(),
                        style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                        decoration: const InputDecoration(
                          hintText: 'lib/main.dart',
                          hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          prefixIcon: Icon(Icons.play_circle_outline_rounded, size: 14, color: AppTheme.textSecondary),
                          prefixIconConstraints: BoxConstraints(minWidth: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Extra CLI arguments
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Flags',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _extraArgsController,
                        enabled: !isRunning,
                        onChanged: (_) => _saveConfig(),
                        style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                        decoration: const InputDecoration(
                          hintText: 'e.g. --no-sound-null-safety',
                          hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          prefixIcon: Icon(Icons.more_horiz_rounded, size: 14, color: AppTheme.textSecondary),
                          prefixIconConstraints: BoxConstraints(minWidth: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Command Preview
          Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              const Text(
                'Command: ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              Expanded(
                child: Text(
                  _buildPreviewCommand(),
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
