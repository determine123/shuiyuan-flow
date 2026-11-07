import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/forum_api.dart';
import 'package:shuiyuan_flow/models.dart';

void main() {
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(await SharedPreferences.getInstance());
  });
  tearDown(() => state.dispose());
  test('默认完全离线', () {
    expect(state.repository.isDemo, true);
    expect(communityAccessEnabled, false);
  });
  test('收藏切换并跨重启保存', () async {
    final t = DemoRepository.demoTopics.first;
    await state.toggleBookmark(t);
    final next = AppState(state.prefs);
    expect(next.isBookmarked(t), true);
    await next.toggleBookmark(t);
    expect(next.bookmarks, isEmpty);
    next.dispose();
  });
  test('重复编辑草稿不会产生副本', () async {
    await state.saveDraft(
      const Draft(id: 'a', title: '标题', body: '初稿', categoryId: 1),
    );
    await state.saveDraft(
      const Draft(id: 'a', title: '标题', body: '修改', categoryId: 1),
    );
    expect(state.drafts.length, 1);
    expect(state.drafts.single.body, '修改');
    final next = AppState(state.prefs);
    expect(next.drafts.single.body, '修改');
    next.dispose();
  });
  test('删除草稿持久化', () async {
    await state.saveDraft(
      const Draft(id: 'a', title: '标题', body: '正文', categoryId: 1),
    );
    await state.deleteDraft('a');
    final next = AppState(state.prefs);
    expect(next.drafts, isEmpty);
    next.dispose();
  });
  test('主题跨重启保存', () async {
    await state.setTheme(ThemeMode.dark);
    final next = AppState(state.prefs);
    expect(next.themeMode, ThemeMode.dark);
    next.dispose();
  });
  test('损坏的本地数据不阻塞启动', () async {
    await state.prefs.setString('demo-bookmarks', '{broken');
    await state.prefs.setString(
      'demo-drafts',
      jsonEncode([
        {'bad': true},
      ]),
    );
    final next = AppState(state.prefs);
    expect(next.bookmarks, isEmpty);
    expect(next.drafts, isEmpty);
    next.dispose();
  });
  test('演示与真实社区数据隔离', () async {
    await state.prefs.setString(
      'live-alice-bookmarks',
      jsonEncode([DemoRepository.demoTopics.first.toJson()]),
    );
    final next = AppState(state.prefs);
    expect(next.bookmarks, isEmpty);
    next.dispose();
  });
  test('未授权构建拒绝连接', () async {
    expect(() => state.connect('key', 'id'), throwsA(isA<ForumException>()));
  });
  test('演示搜索与分类组合', () async {
    final result = await state.repository.topics(
      categoryId: 3,
      query: 'flutter',
    );
    expect(result.single.id, 4);
    expect(await state.repository.topics(page: 1), isEmpty);
  });
  test('演示发布不能发送到社区', () async {
    expect(
      () => state.repository.publish(
        const Draft(id: 'a', title: '标题', body: '正文', categoryId: 1),
      ),
      throwsA(isA<ForumException>()),
    );
  });
}
