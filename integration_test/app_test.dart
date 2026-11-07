import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android 安装后启动、阅读、收藏、草稿、主题与本地持久化', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final state = AppState(prefs);
    await tester.pumpWidget(ShuiyuanApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('源流'), findsOneWidget);
    expect(find.text('离线体验'), findsOneWidget);
    await tester.tap(find.text('欢迎来到源流 · 让交流自然发生'));
    await tester.pumpAndSettle();
    expect(find.text('源流体验官'), findsOneWidget);
    await tester.tap(find.byTooltip('收藏话题'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('我的收藏'), findsOneWidget);
    await tester.tap(find.text('草稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('draft-title')),
      'Android verification',
    );
    await tester.ensureVisible(find.byKey(const Key('draft-body')));
    await tester.enterText(
      find.byKey(const Key('draft-body')),
      'Draft persisted on Android.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('Android verification'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(state.themeMode, ThemeMode.dark);
    final restored = AppState(prefs);
    expect(restored.bookmarks.length, 1);
    expect(restored.drafts.single.body, 'Draft persisted on Android.');
    expect(restored.themeMode, ThemeMode.dark);
    const secure = FlutterSecureStorage();
    await secure.write(key: 'flow_verification', value: 'temporary-test-value');
    expect(await secure.read(key: 'flow_verification'), 'temporary-test-value');
    await secure.delete(key: 'flow_verification');
    expect(await secure.read(key: 'flow_verification'), isNull);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final landscape = MediaQuery.sizeOf(tester.element(find.byType(HomePage)));
    expect(landscape.width, greaterThan(landscape.height));
    expect(tester.takeException(), isNull);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    restored.dispose();
  });
}
