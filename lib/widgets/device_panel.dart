import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'adb_tools_card.dart';
import 'avd_item_card.dart';
import 'connected_devices_card.dart';
import 'create_avd_dialog.dart';

class DevicePanel extends StatelessWidget {
  final AppState state;

  const DevicePanel({super.key, required this.state});

  void _openCreateAvdDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateAvdDialog(state: state),
    );
  }

  void _confirmDeleteAvd(BuildContext context, String avdName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Delete Virtual Device?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$avdName"? This will erase all user data on this virtual device.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              state.deleteAvd(avdName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete AVD'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Connected Devices
          ConnectedDevicesCard(
            state: state,
            devices: state.connectedDevices,
            selectedDeviceId: state.selectedDeviceId,
            onSelectDevice: (id) => state.selectDevice(id),
            onKillDevice: (id) => state.killSelectedDevice(),
            onRefresh: () => state.refreshDevices(),
          ),

          const SizedBox(height: 16),

          // 2. AVD Virtual Devices (No Android Studio required!)
          Card(
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
                          const Icon(Icons.phonelink_setup_rounded, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Virtual Devices (AVD)',
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
                              '${state.avds.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _openCreateAvdDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: const Text('New AVD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => state.refreshDevices(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: 'Scan AVDs (emulator -list-avds)',
                            visualDensity: VisualDensity.compact,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.avds.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 28, color: AppTheme.textMuted),
                          const SizedBox(height: 8),
                          const Text(
                            'No Android Virtual Devices Found',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Create your first virtual device without Android Studio.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _openCreateAvdDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Create Virtual Device'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: state.avds.map((avd) {
                        return AvdItemCard(
                          avd: avd,
                          onLaunch: () => state.launchAvd(avd.id),
                          onColdBoot: () => state.launchAvd(avd.id, coldBoot: true),
                          onWipeData: () => state.launchAvd(avd.id, wipeData: true),
                          onDelete: () => _confirmDeleteAvd(context, avd.id),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. ADB Tools Card
          AdbToolsCard(state: state),
        ],
      ),
    );
  }
}
