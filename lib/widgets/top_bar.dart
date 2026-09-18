import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'apk_builder_dialog.dart';

class TopBar extends StatelessWidget {
  final AppState state;

  const TopBar({super.key, required this.state});

  Future<void> _pickProjectFolder(BuildContext context) async {
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Flutter Project Root',
    );

    if (selectedDirectory != null) {
      await state.selectProject(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = state.currentProjectPath;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // App Brand & Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primarySubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADB Manager',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Flutter Virtual Device Hub',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),
          const VerticalDivider(width: 1, indent: 14, endIndent: 14),
          const SizedBox(width: 24),

          // Project Path & Picker
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: currentProject != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProject.split(RegExp(r'[\\/]')).last,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentProject,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontFamily: 'Consolas',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : const Text(
                          'No Flutter project selected',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickProjectFolder(context),
                  icon: const Icon(Icons.folder_rounded, size: 16),
                  label: const Text('Browse...'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),

                // Recent projects dropdown
                if (state.recentProjects.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Recent Projects',
                    icon: const Icon(Icons.history_rounded, size: 20, color: AppTheme.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    color: AppTheme.surface,
                    onSelected: (path) => state.selectProject(path),
                    itemBuilder: (ctx) {
                      return state.recentProjects.map((path) {
                        final name = path.split(RegExp(r'[\\/]')).last;
                        return PopupMenuItem<String>(
                          value: path,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(path, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontFamily: 'Consolas')),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Build APK / AppBundle Button
          FilledButton.icon(
            onPressed: state.currentProjectPath != null
                ? () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ApkBuilderDialog(state: state),
                    );
                  }
                : null,
            icon: const Icon(Icons.inventory_2_rounded, size: 16),
            label: const Text('Build APK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const SizedBox(width: 12),

          // SDK Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: state.sdkService.isReady ? AppTheme.successSubtle : AppTheme.errorSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.sdkService.isReady ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.sdkService.isReady ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 14,
                  color: state.sdkService.isReady ? AppTheme.success : AppTheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  state.sdkService.isReady ? 'SDK & Tools Ready' : 'SDK Incomplete',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: state.sdkService.isReady ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Antigravity Agent Bridge Status Pill
          Tooltip(
            message: state.isAgentBridgeOnline
                ? 'Antigravity Agent Bridge: Online (Port ${state.agentBridgePort})\nAuto Hot Reload / Restart enabled when AI edits code.'
                : 'Agent Bridge is offline.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.isAgentBridgeOnline ? AppTheme.primarySubtle : AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.isAgentBridgeOnline
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : AppTheme.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isAgentBridgeOnline ? AppTheme.success : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.isAgentBridgeOnline
                        ? 'Bridge :${state.agentBridgePort}'
                        : 'Bridge Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: state.isAgentBridgeOnline ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
