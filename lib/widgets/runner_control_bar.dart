import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/device_session.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'launch_config_bar.dart';

class RunnerControlBar extends StatefulWidget {
  final AppState state;

  const RunnerControlBar({super.key, required this.state});

  @override
  State<RunnerControlBar> createState() => _RunnerControlBarState();
}

class _RunnerControlBarState extends State<RunnerControlBar> {
  String _buildMode = 'debug';
  bool _showConfig = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final targetId = state.selectedDeviceId;
    final session = targetId != null ? state.getSession(targetId) : null;
    final runState = session?.state ?? SessionRunState.stopped;
    final isRunning = session?.isRunning ?? false;
    final isStarting = session?.isStarting ?? false;
    final isReloading = runState == SessionRunState.reloading;
    final isRestarting = runState == SessionRunState.restarting;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (isRunning) state.hotReload(deviceId: targetId);
        },
        const SingleActivator(LogicalKeyboardKey.f5, shift: true): () {
          if (isRunning) state.hotRestart(deviceId: targetId);
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  // 1. Run / Stop Button
                  if (!isRunning && !isStarting)
                    FilledButton.icon(
                      onPressed: state.currentProjectPath != null && targetId != null
                          ? () => state.runFlutterApp(
                                deviceId: targetId,
                                overrideConfig: state.launchConfig.copyWith(mode: _buildMode),
                              )
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Run App', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else if (isStarting)
                    FilledButton.icon(
                      onPressed: () => state.stopFlutterApp(deviceId: targetId),
                      icon: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      label: const Text('Cancel Build', style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => state.stopFlutterApp(deviceId: targetId),
                      icon: const Icon(Icons.stop_rounded, size: 20),
                      label: const Text('Stop App', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                  const SizedBox(width: 12),

                  // 2. Hot Reload Button (F5)
                  Tooltip(
                    message: 'Hot Reload (Shortcut: F5)\nInjects changed code without resetting state',
                    child: FilledButton.icon(
                      onPressed: isRunning && !isReloading && !isRestarting ? () => state.hotReload(deviceId: targetId) : null,
                      icon: isReloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        isReloading ? 'Reloading...' : 'Hot Reload',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.surfaceMuted,
                        disabledForegroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. Hot Restart Button (Shift+F5)
                  Tooltip(
                    message: 'Hot Restart (Shortcut: Shift + F5)\nFull re-initialization of application state',
                    child: FilledButton.icon(
                      onPressed: isRunning && !isReloading && !isRestarting ? () => state.hotRestart(deviceId: targetId) : null,
                      icon: isRestarting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(
                        isRestarting ? 'Restarting...' : 'Hot Restart',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.surfaceMuted,
                        disabledForegroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                  const SizedBox(width: 16),

                  // Build mode selector
                  DropdownButton<String>(
                    value: _buildMode,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(8),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'debug', child: Text('Debug Mode')),
                      DropdownMenuItem(value: 'profile', child: Text('Profile Mode')),
                      DropdownMenuItem(value: 'release', child: Text('Release Mode')),
                    ],
                    onChanged: !isRunning && !isStarting
                        ? (val) {
                            if (val != null) setState(() => _buildMode = val);
                          }
                        : null,
                  ),

                  const SizedBox(width: 12),

                  // Launch Config Toggle Button
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showConfig = !_showConfig),
                    icon: Icon(_showConfig ? Icons.expand_less_rounded : Icons.tune_rounded, size: 16),
                    label: Text(
                      _showConfig ? 'Hide Config' : 'Launch Config',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      backgroundColor: state.launchConfig.dartDefineFromFile != null
                          ? AppTheme.primarySubtle
                          : null,
                    ),
                  ),

                  const Spacer(),

                  // Live Status Badge
                  _buildStateBadge(runState, targetId),
                ],
              ),
            ),
            if (_showConfig) LaunchConfigBar(state: state),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(SessionRunState state, String? deviceId) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (state) {
      case SessionRunState.stopped:
        bg = AppTheme.surfaceMuted;
        fg = AppTheme.textSecondary;
        label = deviceId != null ? 'IDLE' : 'SYSTEM & BUILDS';
        icon = deviceId != null ? Icons.stop_circle_outlined : Icons.terminal_rounded;
        break;
      case SessionRunState.starting:
        bg = AppTheme.warningSubtle;
        fg = AppTheme.warning;
        label = 'INITIALIZING...';
        icon = Icons.hourglass_top_rounded;
        break;
      case SessionRunState.building:
        bg = AppTheme.warningSubtle;
        fg = AppTheme.warning;
        label = 'BUILDING APK...';
        icon = Icons.engineering_rounded;
        break;
      case SessionRunState.running:
        bg = AppTheme.successSubtle;
        fg = AppTheme.success;
        label = 'RUNNING ON ${deviceId ?? "DEVICE"}';
        icon = Icons.check_circle_rounded;
        break;
      case SessionRunState.reloading:
        bg = AppTheme.warningSubtle;
        fg = AppTheme.warning;
        label = 'HOT RELOADING...';
        icon = Icons.bolt_rounded;
        break;
      case SessionRunState.restarting:
        bg = AppTheme.primarySubtle;
        fg = AppTheme.primary;
        label = 'HOT RESTARTING...';
        icon = Icons.sync_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
