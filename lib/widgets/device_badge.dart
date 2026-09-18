import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DeviceBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  const DeviceBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  factory DeviceBadge.ready([String text = 'ONLINE']) {
    return DeviceBadge(
      label: text,
      color: AppTheme.success,
      backgroundColor: AppTheme.successSubtle,
      icon: Icons.check_circle_rounded,
    );
  }

  factory DeviceBadge.offline([String text = 'OFFLINE']) {
    return DeviceBadge(
      label: text,
      color: AppTheme.textMuted,
      backgroundColor: AppTheme.surfaceMuted,
      icon: Icons.circle_outlined,
    );
  }

  factory DeviceBadge.busy([String text = 'BUSY']) {
    return DeviceBadge(
      label: text,
      color: AppTheme.warning,
      backgroundColor: AppTheme.warningSubtle,
      icon: Icons.sync_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
