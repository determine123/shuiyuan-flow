# 参与开发

请先阅读 README 中的实现范围、已知问题和测试状态。

使用 Flutter 3.47.9，运行 `flutter pub get`、`flutter analyze`、`flutter test`。各平台构建依赖见 [构建说明](docs/BUILD.md)。原生桌面测试入口为 `integration_test/desktop_native_test.dart`，Android 测试入口为 `integration_test/app_test.dart`。

`qa/` 含专门重现已知浏览缺陷的验收测试，当前存在预期失败，不能把它们的失败隐藏为全绿状态。参见 [QA 说明](qa/README.md)。

不要提交凭据、Cookie、签名私钥、真实社区帖子或个人测试数据。未经社区许可，保持离线模式；测试使用虚构数据或本地 Mock。任何真实社区写操作需要独立明确的授权和指定测试区域。

提交改动时请说明行为变化、验证命令及结果。功能与测试记录应区分实际运行、静态检查和未验证项。贡献代码按本仓库 GPL-3.0 许可提供，并保留第三方来源及版权说明。
