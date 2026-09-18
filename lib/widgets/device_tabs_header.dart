import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class DeviceTabsHeader extends StatelessWidget {
  final AppState state;

  const DeviceTabsHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final devices = state.connectedDevices;
    final selectedId = state.selectedDeviceId;
    final runningCount = state.runnerService.runningSessions.length;

    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Device Tabs
          Expanded(
            child: devices.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No connected devices. Start an AVD from the sidebar.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final dev = devices[index];
                      final isSelected = dev.id == selectedId;
                      final isRunning = state.isDeviceRunning(dev.id);
                      final isStarting = state.isDeviceStarting(dev.id);

                      return InkWell(
                        onTap: () => state.selectDevice(dev.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.surface : Colors.transparent,
                            border: Border(
                              right: const BorderSide(color: AppTheme.border),
                              top: isSelected
                                  ? const BorderSide(color: AppTheme.primary, width: 2.5)
                                  : BorderSide.none,
                              bottom: isSelected ? BorderSide.none : const BorderSide(color: AppTheme.border),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 16,
                                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dev.displayName,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12,
                                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isRunning
                                      ? AppTheme.success
                                      : isStarting
                                          ? AppTheme.warning
                                          : AppTheme.borderSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Broadcast Actions & Gradle Fixer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Reload All
                Tooltip(
                  message: 'Broadcast Hot Reload to all running devices',
                  child: FilledButton.icon(
                    onPressed: runningCount > 0 ? () => state.reloadAllDevices() : null,
                    icon: const Icon(Icons.bolt_rounded, size: 14),
                    label: Text(
                      'Reload All ($runningCount)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.surfaceSubtle,
                      disabledForegroundColor: AppTheme.textMuted,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Restart All
                Tooltip(
                  message: 'Broadcast Hot Restart to all running devices',
                  child: FilledButton.icon(
                    onPressed: runningCount > 0 ? () => state.restartAllDevices() : null,
                    icon: const Icon(Icons.sync_rounded, size: 14),
                    label: Text(
                      'Restart All ($runningCount)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.surfaceSubtle,
                      disabledForegroundColor: AppTheme.textMuted,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                const VerticalDivider(width: 1, indent: 10, endIndent: 10),
                const SizedBox(width: 8),

                // Fix Gradle Locks
                Tooltip(
                  message: 'Clean locked build cache & stop stuck Gradle daemons',
                  child: OutlinedButton.icon(
                    onPressed: state.currentProjectPath != null ? () => state.fixGradleLocks() : null,
                    icon: const Icon(Icons.build_circle_rounded, size: 14, color: AppTheme.warning),
                    label: const Text('Fix Gradle Locks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
