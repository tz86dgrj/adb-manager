import 'package:flutter_test/flutter_test.dart';
import 'package:adb_manager/main.dart';
import 'package:adb_manager/providers/app_state.dart';
import 'package:adb_manager/services/sdk_service.dart';

void main() {
  testWidgets('AdbManagerApp renders dashboard smoke test', (WidgetTester tester) async {
    final sdkService = SdkService();
    final appState = AppState(sdkService);

    await tester.pumpWidget(AdbManagerApp(appState: appState));
    expect(find.byType(AdbManagerApp), findsOneWidget);
  });
}
