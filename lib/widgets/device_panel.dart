import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'adb_tools_card.dart';
import 'avd_item_card.dart';
import 'connected_devices_card.dart';

class DevicePanel extends StatelessWidget {
  final AppState state;

  const DevicePanel({super.key, required this.state});

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
                      IconButton(
                        onPressed: () => state.refreshDevices(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Scan AVDs (emulator -list-avds)',
                        visualDensity: VisualDensity.compact,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.avds.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Center(
                        child: Text(
                          'No Android Virtual Devices found in SDK path.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
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
