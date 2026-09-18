import 'package:flutter/material.dart';
import '../models/adb_device.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'device_badge.dart';

class ConnectedDevicesCard extends StatelessWidget {
  final AppState state;
  final List<AdbDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<String> onSelectDevice;
  final ValueChanged<String> onKillDevice;
  final VoidCallback onRefresh;

  const ConnectedDevicesCard({
    super.key,
    required this.state,
    required this.devices,
    required this.selectedDeviceId,
    required this.onSelectDevice,
    required this.onKillDevice,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.devices_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Connected Devices',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${devices.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Scan Devices (adb devices)',
                  visualDensity: VisualDensity.compact,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.device_unknown_rounded, size: 28, color: AppTheme.textMuted),
                    SizedBox(height: 6),
                    Text(
                      'No ADB devices connected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Launch an AVD below or plug in a USB device',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isSelected = device.id == selectedDeviceId;
                  final isRunning = state.isDeviceRunning(device.id);
                  final isStarting = state.isDeviceStarting(device.id);
                  final hasProject = state.currentProjectPath != null;

                  return InkWell(
                    onTap: () => onSelectDevice(device.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primarySubtle.withValues(alpha: 0.5) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  device.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isRunning)
                                DeviceBadge.ready('RUNNING')
                              else if (isStarting)
                                DeviceBadge.busy('STARTING')
                              else if (device.isReady)
                                DeviceBadge.ready('ONLINE')
                              else
                                DeviceBadge.busy(device.state.toUpperCase()),
                              if (device.isEmulator) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => onKillDevice(device.id),
                                  icon: const Icon(Icons.power_settings_new_rounded, size: 15),
                                  tooltip: 'Power off emulator',
                                  color: AppTheme.error,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                ),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 24, top: 2),
                            child: Text(
                              'ID: ${device.id}${device.transportId != null ? ' • Transport: ${device.transportId}' : ''}',
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Inline Runner Actions Row
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              children: [
                                if (!isRunning && !isStarting)
                                  FilledButton.icon(
                                    onPressed: hasProject ? () => state.runFlutterApp(deviceId: device.id) : null,
                                    icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                    label: const Text('Run App', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.success,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  )
                                else if (isStarting)
                                  FilledButton.icon(
                                    onPressed: () => state.stopFlutterApp(deviceId: device.id),
                                    icon: const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    label: const Text('Building...', style: TextStyle(fontSize: 11)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.warning,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  )
                                else ...[
                                  // Hot Reload
                                  Tooltip(
                                    message: 'Hot Reload on ${device.id}',
                                    child: FilledButton.icon(
                                      onPressed: () => state.hotReload(deviceId: device.id),
                                      icon: const Icon(Icons.bolt_rounded, size: 13),
                                      label: const Text('Reload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.warning,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Hot Restart
                                  Tooltip(
                                    message: 'Hot Restart on ${device.id}',
                                    child: FilledButton.icon(
                                      onPressed: () => state.hotRestart(deviceId: device.id),
                                      icon: const Icon(Icons.restart_alt_rounded, size: 13),
                                      label: const Text('Restart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Stop
                                  Tooltip(
                                    message: 'Stop app on ${device.id}',
                                    child: IconButton(
                                      onPressed: () => state.stopFlutterApp(deviceId: device.id),
                                      icon: const Icon(Icons.stop_rounded, size: 16),
                                      color: AppTheme.error,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
