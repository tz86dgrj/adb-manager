import 'dart:async';
import 'package:flutter/material.dart';
import '../models/avd_creation_options.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'adb_tools_card.dart';
import 'avd_item_card.dart';
import 'connected_devices_card.dart';
import 'create_avd_dialog.dart';

class DevicePanel extends StatefulWidget {
  final AppState state;

  const DevicePanel({super.key, required this.state});

  @override
  State<DevicePanel> createState() => _DevicePanelState();
}

class _DevicePanelState extends State<DevicePanel> {
  StreamSubscription<AvdCreationResult>? _avdEventSub;

  @override
  void initState() {
    super.initState();
    _avdEventSub = widget.state.avdEvents.listen(_handleAvdEvent);
  }

  @override
  void dispose() {
    _avdEventSub?.cancel();
    super.dispose();
  }

  void _handleAvdEvent(AvdCreationResult event) {
    if (!mounted) return;

    if (event.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Virtual Device "${event.avdName}" is ready!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '▶ Start Now',
            textColor: Colors.white,
            onPressed: () {
              if (event.avdName != null) {
                widget.state.launchAvd(event.avdName!);
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(event.message),
              ),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _openCreateAvdDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true, // Non-blocking: click outside to dismiss
      builder: (_) => CreateAvdDialog(state: widget.state),
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
              widget.state.deleteAvd(avdName);
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
    final state = widget.state;

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
                              '${state.avds.length}${state.isCreatingAvd ? " +1" : ""}',
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

                  // Background Creation Placeholder Card
                  if (state.isCreatingAvd) ...[
                    _CreatingAvdPlaceholderCard(
                      name: state.creatingAvdName ?? 'New Virtual Device',
                      details: state.creatingAvdDetails ?? 'Generating hardware profiles and storage...',
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (state.avds.isEmpty && !state.isCreatingAvd)
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

class _CreatingAvdPlaceholderCard extends StatelessWidget {
  final String name;
  final String details;

  const _CreatingAvdPlaceholderCard({
    required this.name,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'CREATING IN BACKGROUND',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warning,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
