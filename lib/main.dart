import 'package:flutter/material.dart';
import 'providers/app_state.dart';
import 'screens/dashboard_screen.dart';
import 'services/sdk_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sdkService = SdkService();
  final appState = AppState(sdkService);

  // Start initialization in background
  appState.initialize();

  runApp(AdbManagerApp(appState: appState));
}

class AdbManagerApp extends StatelessWidget {
  final AppState appState;

  const AdbManagerApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Manager • Flutter Dev Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Strictly Light Mode as requested
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => DashboardScreen(state: appState),
      ),
    );
  }
}
