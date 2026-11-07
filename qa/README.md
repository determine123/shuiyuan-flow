# 浏览体验专项审计

此目录保存针对现有 0.2.0 的验收用例，不修改生产实现。

`flutter test qa/browsing_acceptance_test.dart --no-pub --reporter expanded` 当前预期为 5 项通过、2 项失败，分别暴露标签切换丢失滚动位置与搜索失败展示旧结果。不要将该失败基线误认为已经修复，也不要只依赖默认 `flutter test` 的回归通过结果来宣称体验验收通过。

`integration_test/browsing_metrics_test.dart` 使用 500 条合成话题和 40 楼合成长帖采样 Debug 帧耗时；这是诊断工具，不是性能达标测试。Flutter 集成测试结束时可能卸载应用，请使用专门的测试模拟器并备份本地数据。

`measure_cold_start.py` 记录指定测试模拟器中的 3 次进程冷启动，保留应用数据。完整结论见 `docs/BROWSING_EXPERIENCE_AUDIT.md`。
