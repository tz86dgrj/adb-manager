import 'package:flutter/material.dart';
import '../models/avd_info.dart';
import '../theme/app_theme.dart';
import 'device_badge.dart';

class AvdItemCard extends StatelessWidget {
  final AvdInfo avd;
  final VoidCallback onLaunch;
  final VoidCallback onColdBoot;
  final VoidCallback onWipeData;
  final VoidCallback? onDelete;

  const AvdItemCard({
    super.key,
    required this.avd,
    required this.onLaunch,
    required this.onColdBoot,
    required this.onWipeData,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primarySubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        avd.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (avd.isRunning)
                      DeviceBadge.ready('RUNNING')
                    else
                      DeviceBadge.offline('AVD'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  avd.id,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onLaunch,
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Start', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textSecondary),
            tooltip: 'Advanced Boot Options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppTheme.border),
            ),
            color: AppTheme.surface,
            onSelected: (val) {
              if (val == 'cold') {
                onColdBoot();
              } else if (val == 'wipe') {
                onWipeData();
              } else if (val == 'delete' && onDelete != null) {
                onDelete!();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'cold',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textSecondary),
                    SizedBox(width: 8),
                    Text('Cold Boot (-no-snapshot-load)', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'wipe',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, size: 16, color: AppTheme.warning),
                    SizedBox(width: 8),
                    Text('Wipe Data & Boot', style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                  ],
                ),
              ),
              if (onDelete != null) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, size: 16, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Delete AVD', style: TextStyle(fontSize: 12, color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
