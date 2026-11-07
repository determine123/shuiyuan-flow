# Android 真机 Profile 采集

2026-11-07：用户确认暂时没有安卓真机，**尚未执行真机 Profile，未产生真机性能结论**。

依据 [Flutter 官方 UI 性能指南](https://docs.flutter.dev/perf/ui-performance)，使用物理 Android 设备及 Profile 模式。模拟器 Debug 数据不能证明真机流畅度。

在未安装源流的专用测试手机上开启 USB 调试、授权电脑，运行：

```powershell
. ./scripts/toolchain-local.ps1
adb devices -l
./scripts/run-physical-profile.ps1 -DeviceId '<实际设备序列号>'
```

脚本拒绝模拟器及已安装主应用的设备，避免覆盖用户数据。需要先在项目目录完成 `flutter pub get`。测试会安装测试应用、写入合成演示数据；请使用专用测试手机。

测试入口为 `integration_test/physical_profile_test.dart`，驱动为 `test_driver/physical_profile_driver.dart`。使用 500 条合成话题和 40 楼合成帖子，预热后采集列表及帖子滚动。输出到 `artifacts/physical-profile`，包含设备条件、运行日志、`metrics.json` 和 `timeline.json`。脚本及测试均检查物理设备和 Profile 条件。

指标包含 FrameTiming 的 build/raster 分位数及超预算样本数；预算取测试开始时显示器刷新率。这些样本不是系统丢帧率，raster 时间也不是 GPU 执行时间。应在 DevTools Performance 中导入 timeline、检查长帧，并记录手机型号、刷新率、温度、电量与运行条件，至少重复三轮。合成数据结果不能代表真实社区网络、图片及登录场景。

当前仅验证静态分析和模拟器拒绝分支；真机采集链路仍须在有设备后实测。
