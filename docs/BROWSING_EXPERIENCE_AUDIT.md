# 水源客户端浏览体验审计

日期：2026-11-07（Asia/Shanghai）。对象：源流 0.2.0+2，生产源码基线 `0c1114b0ec7c6830726c61e317bb08c16a33ffdc`。

结论：基础浏览可用，当前体验验收未全部通过；不能据此宣称已经提供稳定流畅、完善的移动和桌面论坛体验。本次只增加测试与报告，没有修改生产实现，也没有替换交付 APK。

## 与 fluxdo 的关系

当前源流是参考 fluxdo 架构独立实现的轻量 MVP。它不是完整移植的 fluxdo，也未继承上游的全部渲染、图片缓存和实时通知能力。上游 README 中的性能目标不能作为本客户端的测试结果。[参考项目说明](https://github.com/Lingyan000/fluxdo/blob/main/README.md)

## 体验验收：7 项中 5 项通过，2 项失败

已通过：

- 500 条合成话题可滚动；打开话题再返回，列表位置保留。
- 320×720 逻辑尺寸、系统字体 200% 下，首页未出现布局溢出。
- 1280×800 逻辑尺寸下侧栏出现，40 楼合成长话题可阅读和滚动。
- 初次网络加载失败显示错误，并可通过重试恢复。
- 搜索请求乱序返回时，仅显示最后一个关键词对应的结果。

已复现的问题：

1. **切换标签丢失浏览位置。** 将发现页滚动到 1000 px，切至收藏再回发现，偏移变为 0 px。切换标签会重新挂载列表，未设置独立的滚动位置保存机制。相关位置：`lib/main.dart:305`、`lib/main.dart:422`。建议为各页增加稳定的 PageStorageKey 或独立控制器，并分别保存位置。
2. **新搜索失败后混入旧结果。** 输入一个新关键词并模拟接口失败，旧话题“合成测试话题 0000”仍显示在页面中。错误分支仅设置错误文字；列表不为空时继续渲染原有数据，未标示其所属查询。相关位置：`lib/main.dart:151`、`lib/main.dart:190`、`lib/main.dart:412`。建议按查询隔离结果：新查询失败时显示专属错误与重试；普通刷新失败时可保留旧数据，但应明确提示来源与状态。

这些是当前交付版本的可重复失败，不是已经修复的项目。`qa/browsing_acceptance_test.dart` 保留对应断言；执行该审计测试预期会得到非零退出码。原有 28 项回归测试通过并不覆盖这两项体验要求。

## Android 滚动诊断采样

环境：Android 15 / API 35 / x86_64、WHPX、SwiftShader 软件渲染、720×1560 / 280 dpi、Debug 模式。测试期间释放了本次任务的后台 Java 构建进程；记录的宿主机可用物理内存约 1.5 GiB。未进行宿主资源的严格隔离。

数据全部为离线合成内容，不访问真实水源。每个阶段执行 4 次向上 fling，采样前段滚动；并非完整遍历全部条目。通过 `SchedulerBinding.addTimingsCallback` 收集 FrameTiming。

- **500 话题数据集**：209 帧；build P50 3.298 ms、build P95 36.528 ms、raster P95 88.824 ms；197 个样本的 build 或 raster 大于 16.67 ms。
- **40 楼长话题数据集**：210 帧；build P50 2.375 ms、build P95 25.144 ms、raster P95 56.201 ms；185 个样本的 build 或 raster 大于 16.67 ms。
- 合成首页从 pumpWidget 到首次 pumpAndSettle 结束约 3434 ms。这是测试应用内部加载与布局耗时，不是 Android 冷启动时间。

以上结果提示该 Debug 软件渲染环境中存在明显的帧预算超限，不能据此计算真实掉帧率或认定真机发布版同样卡顿。采样用例“通过”只表示成功完成操作并取得非空样本，不代表性能达标。Flutter 官方建议在真实设备的 profile 模式下分析性能；模拟器行为不能代表真机。[Flutter 性能分析说明](https://docs.flutter.dev/perf/ui-performance)

## 正常 APK 复测

采样测试结束后，已重新安装原有正常 APK，并逐字节恢复测试前的 SharedPreferences XML；测试前后交付 APK 的 SHA-256 保持一致：

`08fe31cee79f4ac4740d7c18603ba92b6e61b14abf51034efd99e4156ad7c7e4`

在系统与磁盘缓存已预热、保留本地数据的条件下，执行 3 次强制结束进程后启动：5419 ms、5195 ms、5024 ms，均为 `Status: ok` / `LaunchState: COLD`。这不是首次安装启动或 Release 真机性能测试。最后一次进程日志未发现应用致命异常或 RenderFlex 溢出，首页截图已目视确认。

## 尚不能覆盖的体验

- 真实水源登录、网络延迟、权限差异和生产数据尚未联调；当前构建默认离线。
- 演示模式不加载外部图片、音视频，因此尚未验证图片密集话题、网络图片缓存与失败恢复的体验。
- 桌面检查是 Flutter 组件尺寸模拟，不是 Windows/macOS/Linux 原生安装、键鼠、HiDPI 或多显示器实测。
- iOS 尚未在模拟器或真机验证。
- “优雅”包含视觉一致性、易用性和用户偏好。当前主题、信息层级和自适应导航具备基础，但两项复现问题会打断阅读连续性，不能只凭界面截图判定整体体验成熟。

## 复现与证据

```sh
flutter test qa/browsing_acceptance_test.dart --no-pub --reporter expanded
flutter test integration_test/browsing_metrics_test.dart -d <android-emulator-id> --no-pub --reporter expanded -v
```

原始文件：`artifacts/ux/acceptance.txt`、`native-metrics.txt`、`metrics.json`、`cold-start.json`、`cold-start-*.txt`、`restored-runtime.txt`、`restored-home.png`。采样集成测试框架结束时会卸载测试应用；本次已备份并恢复测试模拟器的原始数据。复跑时请使用专用测试模拟器，不要直接用于个人设备。

建议处理顺序：先修复两项阅读连续性问题，再用真实 Android/iOS 设备执行 profile 性能测试，覆盖真实图片和长会话；最后补齐各桌面系统的原生交互验收。完成这些之前，对外描述宜为“支持基础浏览的 Flutter 跨平台 MVP，持续优化阅读体验”。
