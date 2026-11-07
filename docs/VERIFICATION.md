# Android 验证记录

交付版本：源流 Shuiyuan Flow 0.2.0+2。收尾验证日期：2026-11-07（Asia/Shanghai）。

## 已确认结果

- Flutter 3.47.9 / Dart 3.13.7；Android API 36 构建，最低 API 24。
- 正常应用入口 `lib/main.dart` 的 Debug APK 构建成功。
- Flutter 静态检查无问题；28 项单元与组件测试全部通过。
- 2026-11-06 的 Android 15 / API 35 / x86_64 模拟器集成测试通过：阅读、收藏、草稿、主题、原生安全存储读写与删除、实际屏幕旋转及布局异常检查。测试驱动退出码为 0。
- 2026-11-07 最终正常 APK 重新安装成功，`am start -W` 报告 `Status: ok`、`LaunchState: COLD`，进程存活且首页已目视确认。
- 通过真实界面新建草稿与收藏，强制结束应用进程后重新启动；草稿标题、正文和收藏均恢复，原始 XML、截图与 JSON 结果已保存。
- APK v2 签名校验通过。最终打包仅包含 `arm64-v8a`、`x86_64`，每种架构均包含 `libflutter.so`。
- 最终应用运行日志未检出 `FATAL EXCEPTION`、`Fatal signal`、`Unhandled Exception`、`RenderFlex overflowed`。

## 本次修正

- 修复窄屏顶部标题区域溢出，补充手机、横屏和桌面尺寸检查。
- 修复损坏的本地草稿记录阻塞启动的问题，忽略无法恢复的单条记录。
- 完善草稿返回保护、键盘布局、持久化与演示 / 真实账号数据隔离。
- 禁止携带用户访问密钥的接口请求自动跟随重定向。
- 修复 Flutter Gradle 默认 ABI 集合覆盖项目配置、JNI 插件额外带入 ARMv7 的打包问题，增加 APK 内部文件校验脚本。
- 补齐应用名称、各平台图标、Android 网络权限与禁用备份、Apple 相关配置、五端手动构建 CI。

## 运行环境与性能边界

模拟器采用 WHPX 与 SwiftShader，初始分辨率为 1080×2340。宿主机在构建后可用内存曾降至约 300 MB，最终包第一次首次启动约 20 秒，Android 启动等待超时；随后出现的是模拟器 System UI 的无响应提示。该记录保留在 `launch-first-attempt.txt` 与 `timeout-observed.png`，不计为启动通过。

释放本次任务空闲 Java 构建进程后，冷启动复测约 9.4 秒。为降低软件渲染负载，后续真实界面持久化检查将模拟器调整为 720×1560、280 dpi 并关闭系统动画；跨进程重启约 7.4 秒，数据恢复检查通过。这是资源受限模拟器上的 Debug 测量，不代表手机或 Release 性能，仍需单独进行发布版性能优化与真机检查。

## 文件与复验

- APK：`dist/Shuiyuan_Flow_v0.2.0_debug.apk`
- SHA-256：`08fe31cee79f4ac4740d7c18603ba92b6e61b14abf51034efd99e4156ad7c7e4`
- 包名：`io.determine.shuiyuan_flow`
- 核心测试：`test/`；模拟器集成：`integration_test/app_test.dart`
- 安装与启动：`scripts/verify-android.ps1`
- 跨进程持久化：`scripts/check-android-persistence.py`（会在指定测试模拟器中写入测试草稿、收藏，不会清除应用数据）
- ABI 检查：`scripts/check-apk.py`
- 原始证据：源码 ZIP 内的 `artifacts/checks/` 与 `artifacts/android/`。

## 尚未验证或实现

ARM64 真机尚未安装验证；iOS、Windows、macOS、Linux 本次提供工程与构建配置，未完成对应系统的原生构建及安装验证。CI 配置已编写，尚未推送或远程执行。

默认交付为离线演示模式，数据均为虚构。真实水源登录与读写尚未联调，需要社区许可及站方接口配置；尚未实现 jAccount 浏览器授权回调、图片上传、投票、徽章、私信和实时推送。不得将本次测试解读为上述功能已经完成。
