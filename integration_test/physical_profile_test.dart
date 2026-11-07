import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/main.dart';

import '../qa/browsing_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('安卓真机 Profile 浏览时间线与帧耗时', (tester) async {
    expect(
      kProfileMode,
      isTrue,
      reason: '必须通过 --profile 运行，不能将 Debug 当作 Profile',
    );
    expect(Platform.isAndroid, isTrue, reason: '本入口当前只验证安卓真机');
    final qemu = await Process.run('/system/bin/getprop', ['ro.kernel.qemu']);
    final hardware = await Process.run('/system/bin/getprop', ['ro.hardware']);
    expect(qemu.stdout.toString().trim(), isNot('1'), reason: '拒绝安卓模拟器');
    expect(
      RegExp(
        'goldfish|ranchu',
        caseSensitive: false,
      ).hasMatch(hardware.stdout.toString()),
      isFalse,
      reason: '拒绝模拟器硬件后端',
    );
    final state = AppState(
      await SharedPreferences.getInstance(),
      repository: BrowsingFixture(),
    );
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> values) => frames.addAll(values);
    SchedulerBinding.instance.addTimingsCallback(record);
    final hz = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .display
        .refreshRate;
    final refreshHz = hz > 0 ? hz : 60.0;
    final budgetUs = (1000000 / refreshHz).round();
    Map<String, Object> summarize(String phase) {
      final build =
          frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      final raster =
          frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      double percentile(List<double> values, double q) =>
          values.isEmpty ? 0 : values[((values.length - 1) * q).round()];
      return {
        'phase': phase,
        'frame_count': frames.length,
        'build_p50_ms': percentile(build, .5),
        'build_p95_ms': percentile(build, .95),
        'raster_p50_ms': percentile(raster, .5),
        'raster_p95_ms': percentile(raster, .95),
        'samples_over_display_budget_build_or_raster': frames
            .where(
              (f) =>
                  f.buildDuration.inMicroseconds > budgetUs ||
                  f.rasterDuration.inMicroseconds > budgetUs,
            )
            .length,
      };
    }

    final phases = <Map<String, Object>>[];
    try {
      await binding.traceAction(() async {
        final initialTask = developer.TimelineTask()
          ..start('Shuiyuan.synthetic-first-view');
        try {
          await tester.pumpWidget(ShuiyuanApp(state: state));
          await tester.pumpAndSettle();
        } finally {
          initialTask.finish();
        }
        final feed = find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first;
        // 先预热一轮并回到顶部，再收集后续样本，减少首次编译与缓存建立的影响。
        await tester.fling(feed, const Offset(0, -800), 1200);
        await tester.pumpAndSettle();
        await tester.fling(feed, const Offset(0, 800), 1200);
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(seconds: 1));
        frames.clear();
        for (var i = 0; i < 8; i++) {
          final task = developer.TimelineTask()
            ..start('Shuiyuan.feed-scroll-$i');
          try {
            await tester.fling(feed, const Offset(0, -900), 1200);
            await tester.pumpAndSettle();
          } finally {
            task.finish();
          }
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        phases.add(summarize('500-topic-feed'));
        await tester.tap(find.textContaining('合成测试话题').hitTestable().first);
        await tester.pumpAndSettle();
        final thread = find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.fling(thread, const Offset(0, -800), 1200);
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(seconds: 1));
        frames.clear();
        for (var i = 0; i < 8; i++) {
          final task = developer.TimelineTask()
            ..start('Shuiyuan.thread-scroll-$i');
          try {
            await tester.fling(thread, const Offset(0, -900), 1200);
            await tester.pumpAndSettle();
          } finally {
            task.finish();
          }
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        phases.add(summarize('40-post-thread'));
      }, reportKey: 'browsing_timeline');
      final metrics = {
        'mode': 'profile',
        'android_qemu': false,
        'refresh_hz': refreshHz,
        'frame_budget_ms': budgetUs / 1000,
        'data_source': 'synthetic-offline',
        'phases': phases,
        'limitation': '不包含真实社区网络、图片密集话题、电池与长会话测试；超预算样本数不是实际掉帧率',
      };
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['ux_metrics'] = metrics;
      debugPrint('PROFILE_METRICS ${jsonEncode(metrics)}');
      expect(phases.every((p) => (p['frame_count'] as int) > 0), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(record);
    }
  });
}
