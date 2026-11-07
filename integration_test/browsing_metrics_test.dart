import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuiyuan_flow/app_state.dart';
import 'package:shuiyuan_flow/main.dart';

import '../qa/browsing_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('合成500话题和40楼长帖的Debug帧耗时采样', (t) async {
    final state = AppState(
      await SharedPreferences.getInstance(),
      repository: BrowsingFixture(),
    );
    final samples = <FrameTiming>[];
    void record(List<FrameTiming> timings) => samples.addAll(timings);
    SchedulerBinding.instance.addTimingsCallback(record);
    final load = Stopwatch()..start();
    await t.pumpWidget(ShuiyuanApp(state: state));
    await t.pumpAndSettle();
    load.stop();
    await Future<void>.delayed(const Duration(seconds: 1));
    samples.clear();
    final feed = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 4; i++) {
      await t.fling(feed, const Offset(0, -900), 1200);
      await t.pumpAndSettle();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    Map<String, Object> metrics(String phase) {
      final build =
          samples.map((e) => e.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      final raster =
          samples.map((e) => e.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      double p(List<double> xs, double q) =>
          xs.isEmpty ? 0 : xs[((xs.length - 1) * q).round()];
      return {
        'phase': phase,
        'mode': 'debug',
        'frame_count': samples.length,
        'build_p50_ms': p(build, .5),
        'build_p95_ms': p(build, .95),
        'raster_p95_ms': p(raster, .95),
        'frames_over_16_67ms_build_or_raster': samples
            .where(
              (e) =>
                  e.buildDuration.inMicroseconds > 16670 ||
                  e.rasterDuration.inMicroseconds > 16670,
            )
            .length,
      };
    }

    final feedResult = metrics('feed_scroll_500_topics');
    samples.clear();
    await t.tap(find.textContaining('合成测试话题').hitTestable().first);
    await t.pumpAndSettle();
    final thread = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        )
        .first;
    await Future<void>.delayed(const Duration(seconds: 1));
    samples.clear();
    for (var i = 0; i < 4; i++) {
      await t.fling(thread, const Offset(0, -900), 1200);
      await t.pumpAndSettle();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    final threadResult = metrics('thread_scroll_40_posts');
    SchedulerBinding.instance.removeTimingsCallback(record);
    debugPrint(
      'UX_METRICS ${jsonEncode({
        'fixture_topics': 500,
        'fixture_posts': 40,
        'initial_fixture_settle_ms': load.elapsedMilliseconds,
        'samples': [feedResult, threadResult],
        'limitation': 'Debug + emulator + synthetic offline data; not a release or real-device performance certificate',
      })}',
    );
    expect((feedResult['frame_count'] as int), greaterThan(0));
    expect((threadResult['frame_count'] as int), greaterThan(0));
    expect(t.takeException(), isNull);
  });
}
