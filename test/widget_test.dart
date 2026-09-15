import 'package:flutter_test/flutter_test.dart';
import 'package:file_sync/main.dart';
import 'package:file_sync/providers/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('LanSync basic pump smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    // 基础 pump 测试
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const LanSyncApp(),
      ),
    );

    expect(find.text('设备雷达与互传'), findsOneWidget);
  });
}
