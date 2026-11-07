import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/main.dart';

void main() {
  Future<AppState> start(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await tester.pumpWidget(ShuiyuanApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  for (final size in [
    const Size(360, 640),
    const Size(640, 360),
    const Size(1280, 800),
  ]) {
    testWidgets('首页 ${size.width}x${size.height} 无布局异常', (tester) async {
      await start(tester, size);
      expect(find.text('源流'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width >= 800)
        expect(find.byType(NavigationRail), findsOneWidget);
    });
  }
  testWidgets('搜索与分类筛选有效', (tester) async {
    await start(tester, const Size(400, 850));
    await tester.enterText(find.byKey(const Key('search')), 'Flutter');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('用 Flutter 构建五端一致的阅读体验'), findsOneWidget);
    expect(find.text('欢迎来到源流 · 让交流自然发生'), findsNothing);
  });
  testWidgets('收藏可以从独立页面访问', (tester) async {
    final state = await start(tester, const Size(400, 850));
    await tester.tap(find.byTooltip('收藏话题').first);
    await tester.pumpAndSettle();
    expect(state.bookmarks.length, 1);
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('我的收藏'), findsOneWidget);
  });
  testWidgets('键盘弹出与横屏编辑不溢出，返回保存草稿', (tester) async {
    final state = await start(tester, const Size(640, 360));
    await tester.tap(find.byKey(const Key('compose')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('draft-title')), '回归草稿');
    await tester.ensureVisible(find.byKey(const Key('draft-body')));
    await tester.enterText(find.byKey(const Key('draft-body')), '键盘和横屏回归内容');
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('保留这次编辑？'), findsOneWidget);
    await tester.tap(find.text('保存草稿'));
    await tester.pumpAndSettle();
    expect(state.drafts.single.body, '键盘和横屏回归内容');
    expect(tester.takeException(), isNull);
  });
}
