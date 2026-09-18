import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/device_panel.dart';
import '../widgets/device_tabs_header.dart';
import '../widgets/log_console_view.dart';
import '../widgets/runner_control_bar.dart';
import '../widgets/top_bar.dart';

class DashboardScreen extends StatelessWidget {
  final AppState state;

  const DashboardScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isInitializing) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Initializing Android SDK and Environment...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // 1. Top Header Bar
          TopBar(state: state),

          // 2. Main Content Split View
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Panel: AVDs & ADB Management (Fixed Width: 400px)
                SizedBox(
                  width: 400,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.background,
                      border: Border(right: BorderSide(color: AppTheme.border)),
                    ),
                    child: DevicePanel(state: state),
                  ),
                ),

                // Right Panel: Device Tabs, Runner Hero Bar & Real-Time Log Console
                Expanded(
                  child: Column(
                    children: [
                      DeviceTabsHeader(state: state),
                      RunnerControlBar(state: state),
                      Expanded(
                        child: LogConsoleView(state: state),
                      ),
                    ],
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
