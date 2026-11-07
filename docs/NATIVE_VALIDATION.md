# 原生桌面验证与 Android Profile 状态

日期：2026-11-07。生产代码基线：`0c1114b0ec7c6830726c61e317bb08c16a33ffdc`，版本 0.2.0+2。此次新增测试、采集脚本和文档，未修改生产 Dart 代码；默认离线虚构演示数据。

## 已验证结果

- Windows 11 x64（10.0.22631.6199）：`flutter build windows --release --no-pub` 成功；实际 Windows Flutter 后端集成测试 **1/1 通过**，耗时 9 秒（不含构建）。Release EXE 已启动并显示中文界面。真实系统按键 `F` 触发搜索并筛选出 Flutter 话题，Tab 后焦点进入清空按钮。
- Linux x64：Ubuntu 24.04.4 / WSL2 / WSLg，`flutter build linux --release --no-pub` 成功；实际 Linux Flutter 后端集成测试 **1/1 通过**，耗时 12 秒（不含构建）。Release ELF 已启动，鼠标切换发现页、点击分类、滚轮滚动可响应；1280×720 侧栏布局缩为 640×720 后切换到底部导航，直接 X11 截图已保存。
- `flutter analyze --no-pub`：No issues found。
- Visual Studio Build Tools 2022 17.14.44、Windows SDK 10.0.26100.0 已安装，Flutter doctor 的 Visual Studio 项通过。安全存储插件额外需要 ATL，补装后 Release 构建成功。未开启 Windows 开发者模式，工作副本使用插件目录 junction 解决链接权限。

两端均使用 Flutter 3.47.9 / Dart 3.13.7。Windows 与 Linux 分别在隔离工作目录构建，避免跨系统生成文件互相覆盖。Linux 使用独立 QA 配置目录。

## 集成测试范围

`integration_test/desktop_native_test.dart` 检查实际桌面 Platform，覆盖原生启动、响应式导航、搜索、分类、阅读、收藏、临时草稿、主题、外部链接确认/取消，以及本地数据重新读取。使用真实 SharedPreferences 插件；结束恢复原有收藏/主题并清理自建临时草稿。键盘 Tab 在集成测试中由 Flutter 测试框架注入，另有上面的 Windows Release 系统按键检查。

Linux 首次尝试在清空搜索后分类断言失败；交互改为点击实际“清空搜索”按钮后重跑通过。此处没有修改生产实现，也没有证明原失败一定是产品缺陷。

可复现命令：

```text
flutter build windows --release --no-pub
flutter test integration_test/desktop_native_test.dart -d windows --no-pub --reporter expanded
flutter build linux --release --no-pub
flutter test integration_test/desktop_native_test.dart -d linux --no-pub --reporter expanded
```

## 不能据此推断的结论

- 用户确认没有安卓真机，**真机 Profile 未执行**。已准备物理设备保护检查、FrameTiming 及 timeline 导出，静态分析通过，模拟器拒绝分支已验证。详见 [真机采集说明](PHYSICAL_PROFILE.md)。[Flutter 官方方法](https://docs.flutter.dev/perf/ui-performance)要求在物理设备上使用 Profile 模式评估移动端性能。
- Linux 是实际 Linux 原生后端，但宿主为 WSLg，Mesa llvmpipe 软件渲染；不能代表独立 Linux 电脑的 GPU 性能。Linux 独立系统键盘输入检查未通过自动化环境验证；Flutter 原生集成输入通过。
- Windows Release 自动化文字批量输入未确认成功，单键输入和筛选已观察成功。Windows 拖动缩窄窗口受到其他桌面窗口遮挡影响，未计入通过项。
- 未做桌面 Profile 时间线、长时间内存/功耗测试、IME 中文输入、剪贴板、辅助功能完整审计、多显示器/DPI 切换、托盘、系统菜单或跨机器安装兼容性验收。外链只验证确认/取消，没有打开社区或写入社区。
- macOS、iOS 未具备对应宿主及设备，未验证。真实社区登录、网络与图片加载仍未联调。
- 先前 UX 审计的两项问题仍存在：切换标签后列表位置丢失；搜索失败时旧结果仍显示。见 [浏览体验审计](BROWSING_EXPERIENCE_AUDIT.md)。功能冒烟通过不足以宣称“所有场景流畅优雅”。

## 产物

- `dist/Shuiyuan_Flow_v0.2.0_windows-x64.zip`：完整 Release 目录，须整体解压后运行 `shuiyuan_flow.exe`；未制作签名安装器，也未在干净 Windows 机器验证运行库依赖。
  SHA-256：`7165885e61b69a83962f068b8742c71a9360ecd1649b79c56a58d73f0604ff71`
- `dist/Shuiyuan_Flow_v0.2.0_linux-x64.tar.gz`：完整 Release bundle，解压后执行 `bundle/shuiyuan_flow`。依赖 GTK3、libsecret、libjsoncpp 等宿主库，最低兼容发行版尚未验证。
  SHA-256：`9b4de7795ca81c44271b1bf92de8484244ce8c090d106d4bb215a4ecec5b0edd`
- 原 Android Debug APK 未变更，SHA-256：`08fe31cee79f4ac4740d7c18603ba92b6e61b14abf51034efd99e4156ad7c7e4`。

原始日志和 Linux 直接窗口截图在 `artifacts/native-validation/`。这些产物仅用于离线 MVP 测试，Windows/Linux 构建与集成日志分别保存，可核对成功输出。
