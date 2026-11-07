// 本文件由 flutter test qa/... 执行，保留在默认回归目录之外用于记录失败验收项。
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/main.dart';
import 'package:shuiyuan_flow/models.dart';

import 'browsing_fixture.dart';

class RaceFixture extends BrowsingFixture {
  final pending = <String, Completer<List<Topic>>>{};
  @override
  Future<List<Topic>> topics({
    int page = 0,
    int? categoryId,
    String query = '',
  }) {
    if (query.isEmpty) return super.topics(page: page, categoryId: categoryId);
    return (pending[query] = Completer<List<Topic>>()).future;
  }
}

void main() {
  Future<AppState> start(
    WidgetTester t, {
    BrowsingFixture? repo,
    Size size = const Size(400, 850),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      await SharedPreferences.getInstance(),
      repository: repo ?? BrowsingFixture(),
    );
    await t.pumpWidget(ShuiyuanApp(state: state));
    await t.pumpAndSettle();
    return state;
  }

  Finder feedScroll() => find
      .descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      )
      .first;
  double offset(WidgetTester t) =>
      t.state<ScrollableState>(feedScroll()).position.pixels;

  testWidgets('500话题列表可滚动，打开话题再返回保留列表位置', (t) async {
    await start(t);
    await t.drag(feedScroll(), const Offset(0, -1000));
    await t.pumpAndSettle();
    final before = offset(t);
    expect(before, greaterThan(300));
    final visible = find.textContaining('合成测试话题').hitTestable().first;
    await t.tap(visible);
    await t.pumpAndSettle();
    expect(find.text('测试用户0'), findsOneWidget);
    await t.tap(find.byTooltip('返回'));
    await t.pumpAndSettle();
    expect(offset(t), closeTo(before, 1));
    expect(t.takeException(), isNull);
  });
  testWidgets('切换收藏再回发现应保留浏览位置', (t) async {
    await start(t);
    await t.drag(feedScroll(), const Offset(0, -1000));
    await t.pumpAndSettle();
    final before = offset(t);
    await t.tap(find.text('收藏'));
    await t.pumpAndSettle();
    await t.tap(find.text('发现'));
    await t.pumpAndSettle();
    expect(offset(t), closeTo(before, 1), reason: '切换标签不应把阅读列表重置到顶部');
  });
  testWidgets('320宽度且系统字体200%时无布局异常', (t) async {
    await start(t, size: const Size(320, 720), scale: 2);
    expect(t.takeException(), isNull);
  });
  testWidgets('桌面宽屏与横屏可阅读长话题', (t) async {
    await start(t, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    await t.tap(find.textContaining('合成测试话题 0000'));
    await t.pumpAndSettle();
    await t.drag(
      find.byType(ListView).hitTestable().first,
      const Offset(0, -1800),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('初次加载失败可以重试恢复', (t) async {
    final repo = BrowsingFixture()..fail = true;
    await start(t, repo: repo);
    expect(find.text('暂时无法加载'), findsOneWidget);
    repo.fail = false;
    await t.tap(find.text('重试'));
    await t.pumpAndSettle();
    expect(find.textContaining('合成测试话题 0000'), findsOneWidget);
  });
  testWidgets('搜索请求乱序返回时只显示最新关键词结果', (t) async {
    final repo = RaceFixture();
    await start(t, repo: repo);
    await t.enterText(find.byKey(const Key('search')), 'older');
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const Key('search')), 'newer');
    await t.pump(const Duration(milliseconds: 400));
    repo.pending['newer']!.complete([
      const Topic(id: 2, title: 'newer结果', categoryId: 1),
    ]);
    await t.pumpAndSettle();
    repo.pending['older']!.complete([
      const Topic(id: 1, title: 'older结果', categoryId: 1),
    ]);
    await t.pumpAndSettle();
    expect(find.text('newer结果'), findsOneWidget);
    expect(find.text('older结果'), findsNothing);
  });
  testWidgets('新关键词搜索失败时不能混入旧查询结果', (t) async {
    final repo = BrowsingFixture();
    await start(t, repo: repo);
    repo.fail = true;
    await t.enterText(find.byKey(const Key('search')), '不存在的新关键词');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(
      find.textContaining('合成测试话题 0000'),
      findsNothing,
      reason: '旧列表应清楚标为旧数据或从新搜索结果中移除',
    );
  });
}
