import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/main.dart';
import 'package:shuiyuan_flow/models.dart';
import 'package:shuiyuan_flow/forum_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('原生桌面启动、输入、分类、阅读、收藏、草稿、主题与链接确认', (tester) async {
    expect(
      Platform.isWindows || Platform.isLinux || Platform.isMacOS,
      isTrue,
      reason: '必须在实际桌面 Flutter 后端运行，不能在组件尺寸模拟中宣称原生通过',
    );
    final state = AppState(await SharedPreferences.getInstance());
    final previousTheme = state.themeMode;
    final bookmarkedBefore = state.isBookmarked(
      DemoRepository.demoTopics.first,
    );
    final draftId =
        'native-desktop-qa-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await tester.pumpWidget(ShuiyuanApp(state: state));
      await tester.pumpAndSettle();
      expect(find.text('源流'), findsOneWidget);
      final size = MediaQuery.sizeOf(tester.element(find.byType(HomePage)));
      if (size.width >= 800) {
        expect(find.byType(NavigationRail), findsOneWidget);
      } else {
        expect(find.byType(NavigationBar), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('search')));
      await tester.enterText(find.byKey(const Key('search')), 'Flutter');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('用 Flutter 构建五端一致的阅读体验'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('学习交流').first);
      await tester.pumpAndSettle();
      expect(find.text('分享我的课程笔记整理方法'), findsOneWidget);
      expect(find.text('秋日校园散步，你最喜欢哪条路线？'), findsNothing);
      await tester.tap(find.text('全部话题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('欢迎来到源流 · 让交流自然发生'));
      await tester.pumpAndSettle();
      expect(find.text('源流体验官'), findsOneWidget);
      if (!bookmarkedBefore) {
        await tester.tap(find.byTooltip('收藏话题'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmarks_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('欢迎来到源流 · 让交流自然发生'), findsOneWidget);
      await state.saveDraft(
        Draft(
          id: draftId,
          title: 'Native desktop verification',
          body: 'Temporary native desktop QA draft.',
          categoryId: 1,
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_note).first);
      await tester.pumpAndSettle();
      expect(find.text('Native desktop verification'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(state.themeMode, ThemeMode.dark);
      final link = find.text('查看水源社区协议');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('打开外部链接'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      final restored = AppState(await SharedPreferences.getInstance());
      expect(restored.drafts.any((d) => d.id == draftId), isTrue);
      expect(restored.themeMode, ThemeMode.dark);
      restored.dispose();
      expect(tester.takeException(), isNull);
    } finally {
      await state.deleteDraft(draftId);
      if (state.isBookmarked(DemoRepository.demoTopics.first) !=
          bookmarkedBefore) {
        await state.toggleBookmark(DemoRepository.demoTopics.first);
      }
      await state.setTheme(previousTheme);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      state.dispose();
    }
  });
}
