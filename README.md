# 源流 · Shuiyuan Flow

上海交通大学水源社区非官方 Flutter 客户端，目标平台：Android、iOS、Windows、macOS、Linux。

默认运行**离线体验模式**，数据均为虚构，不访问真实论坛。真实社区需要书面许可、站方 User API 配置和用户授权。

## 功能

- 自适应手机底部导航 / 桌面侧边导航，Material 3，深浅色与系统主题。
- 话题列表、分类筛选、搜索、防抖与过期响应保护、分页、下拉刷新。
- HTML 帖子阅读、长话题分批加载、外部链接确认。
- 本地收藏、草稿保存 / 修改 / 删除、返回保护、重启恢复。
- 真实接口适配：User API Key 校验、读取、创建话题、回复、点赞。
- 凭据使用系统安全存储；真实账号与演示数据分开保存。
- 无分析上报、无广告、无上游自动更新、无密码收集。

当前未实现：jAccount 浏览器授权回调、图片上传、投票、徽章、私信、实时推送。真实接口尚未与水源站方联调。

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
