# 源流 · Shuiyuan Flow

面向上海交通大学水源社区的非官方现代化移动与桌面客户端，基于 Flutter 开发，目标覆盖 Android、iOS、Windows、macOS、Linux，让手机阅读与桌面浏览拥有一致、自然的体验。

“流畅、优雅”是项目的设计目标。当前以离线 MVP 验证阅读、内容整理与跨平台交互，性能结论以实际设备和测试记录为准。

[项目介绍](https://determine123.github.io/note/writing/2026-11-07-shuiyuan-flow/) · [构建指南](docs/BUILD.md) · [反馈问题](https://github.com/determine123/shuiyuan-flow/issues) · [参与开发](CONTRIBUTING.md)

默认运行**离线体验模式**，数据均为虚构，不访问真实论坛。真实社区需要书面许可、站方 User API 配置和用户授权。

> 当前是开发中的离线 MVP，不是水源官方客户端，也不是 fluxdo 的完整移植。尚未取得真实社区接入许可，未完成真实站点联调。

## 验证状态

- Android：Debug APK 已在 Android 15 模拟器安装、启动及持久化验证；没有真机 Profile 性能结论。
- Windows：Release 编译、原生集成测试及启动通过。
- Linux：Release 编译及原生集成测试通过，环境为 WSLg，不能代表独立 Linux 电脑性能。
- iOS / macOS：已含工程，尚未在对应宿主验证。
- 已知浏览问题：切换标签后列表滚动位置丢失；搜索失败时仍显示旧结果。详见 [浏览体验审计](docs/BROWSING_EXPERIENCE_AUDIT.md)。

详细记录：[Android 验证](docs/VERIFICATION.md) · [原生桌面验证](docs/NATIVE_VALIDATION.md) · [真机 Profile](docs/PHYSICAL_PROFILE.md) · [真实社区接入准备](docs/ANDROID_LIVE_INTEGRATION.md)。报告中提到的本机 `dist/` 与 `artifacts/` 不随 Git 源码上传；公开仓库不能视为已提供所有平台安装包。

## 功能

- 自适应手机底部导航 / 桌面侧边导航，Material 3，深浅色与系统主题。
- 话题列表、分类筛选、搜索、防抖与过期响应保护、分页、下拉刷新。
- HTML 帖子阅读、长话题分批加载、外部链接确认。
- 本地收藏、草稿保存 / 修改 / 删除、返回保护、重启恢复。
- 真实接口适配：User API Key 校验、读取、创建话题、回复、点赞。
- 凭据使用系统安全存储；真实账号与演示数据分开保存。
- 无分析上报、无广告、无上游自动更新、无密码收集。

当前未实现：jAccount 浏览器授权回调、图片上传、投票、徽章、私信、实时推送。真实接口尚未与水源站方联调。

## 设计与技术

- **跨设备阅读**：根据窗口宽度切换导航方式，保持发现、收藏、草稿和设置的使用路径一致。
- **可恢复的编辑**：草稿本地保存，返回时保护未保存内容；外部链接先确认再打开。
- **分层实现**：`ForumRepository` 隔离演示数据与 Discourse 接口，`AppState` 管理账号、本地内容和主题，Flutter 页面负责呈现与交互。
- **技术栈**：Flutter / Dart、Material 3、ChangeNotifier、`http`、`flutter_widget_from_html_core`、`shared_preferences`、`flutter_secure_storage` 与 `url_launcher`。
- **访问与隐私**：默认离线；启用真实接入需要许可与用户授权。客户端不收集 jAccount 密码，凭据保存在系统安全存储中。

## 如何理解与 fluxdo 的关系

[FluxDO](https://github.com/Lingyan000/fluxdo) 面向 Linux.do，源流面向水源社区。源流参考其跨平台产品组织与阅读体验方向，在本仓库独立实现轻量核心，使用自己的界面、数据层与演示内容。

上游 README 介绍的图片管理、通知、投票、徽章、分块渲染与代理等能力，不能据此视为源流已经具备。当前源流有 HTML 阅读和楼层分批请求，但没有移植上游的 HTML 分块渲染、专用图片缓存、MessageBus 通知或 Rust 网络代理。上游使用的 Riverpod、Dio 等技术也不是本项目当前的实现栈。

## 获取与体验

当前 GitHub 交付为源码，尚未发布 GitHub Release 安装附件。可以按下方命令运行离线演示；源码包含五端工程，不代表五端安装包均已完成。不要使用 fluxdo 的安装包或 AltStore 源安装源流，它们属于不同项目。

## 后续计划

1. 修复已知的列表位置恢复与搜索错误状态问题，完善桌面输入、焦点与窗口交互验证。
2. 在具备安卓真机后执行 Profile 采样，补充 iOS / macOS 宿主验证与可复现构建记录。
3. 取得社区许可并确认接口配置后，完善浏览器授权回调，开展真实账号读取联调。
4. 根据接口许可与实际需求逐步评估图片上传、投票、徽章和通知；这些是规划，尚无完成时间承诺。

## 运行与测试

需要 Flutter 3.47.9（Dart 3.13+），以及对应平台原生构建工具。

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
flutter test integration_test/app_test.dart -d <android-emulator-id>
```

Android 安装与启动复验脚本见 `scripts/verify-android.ps1`，详细说明见 `docs/BUILD.md`。测试状态只以 `docs/VERIFICATION.md` 和原始日志为准。

本机已配置独立工具链时，可在 PowerShell 中运行 `. ./scripts/toolchain-local.ps1`，仅为当前终端设置路径。该脚本路径对应本次工作电脑，其他电脑请使用自己的 Flutter / Android 工具链。

## 源码结构

`lib/forum_api.dart`：仓库接口、Discourse 网络适配、虚构演示数据。  
`lib/app_state.dart`：本地状态与安全凭据。  
`lib/models.dart`：话题、分类、帖子、草稿模型。  
`lib/main.dart`：自适应 UI、阅读与编辑流程。

## 参考与许可证

参考 [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo)（GPL-3.0），固定参考提交 `bc5a04b0fc09bde915415e2ab345bc24c8c8146c`。参考其 Flutter 五端工程组织、自适应界面与 Discourse 客户端分层思路，本工程独立实现轻量核心；未引入上游 Rust 代理、Linux.do 积分系统、Cloudflare 绕过逻辑或遥测服务。上游名称和图标不作为本产品身份使用。

本工程采用 GPL-3.0，参见 `LICENSE`。Flutter 与第三方包版权归各自作者，应用内提供开源许可证页。本项目不代表水源社区或上海交通大学官方。

## 问题反馈

欢迎通过 [Issues](https://github.com/determine123/shuiyuan-flow/issues) 提交问题。请说明平台、系统版本、应用版本、复现步骤、预期与实际结果，并注明演示模式或经许可的真实模式。日志和截图请先移除密钥、Cookie、账号标识与私人内容。贡献流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。
