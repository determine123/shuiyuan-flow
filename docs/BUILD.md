# 五端构建与联调

`.github/workflows/build.yml` 提供手动触发的五端构建矩阵，不会自动发布或推送仓库。本次尚未在远端运行；iOS 产物没有签名，不是可直接分发安装的 IPA。

## Android

JDK 17、Android SDK、Flutter 3.47.9。安装相应 SDK / NDK 组件，接受工具链许可。

```sh
flutter build apk --debug --target-platform android-arm64,android-x64
python scripts/check-apk.py build/app/outputs/flutter-apk/app-debug.apk
adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <serial> shell am start -W -n io.determine.shuiyuan_flow/.MainActivity
```

APK 为测试签名，不是商店发行签名；升级需保持同一签名，不能假定与历史聊天中 APK 的签名一致。旧版签名冲突时请先导出重要数据，不自动卸载用户应用。

交付架构限定为 ARM64 与 x86_64。`disable-abi-filtering=true` 只关闭 Flutter 插件自动覆盖集合的行为，实际过滤由 `app/build.gradle.kts` 的 `ndk.abiFilters` 执行。打包后应运行上述检查，确认每个声明架构都有 `libflutter.so`，避免 JNI 插件单独带入 ARMv7 导致安装后无法启动。

## iOS / macOS

必须在 macOS 上安装 Xcode 与 CocoaPods，iOS 真机需配置个人或团队签名。安全存储依赖 Keychain 权限。

```sh
flutter build ios --no-codesign
flutter build macos
```

无签名 iOS 产物不能直接安装到普通 iPhone；需进一步完成签名与分发。

## Windows / Linux

Windows 需要 Visual Studio 的 Desktop development with C++ 工作负载和 Windows SDK。
Linux 需要 clang、cmake、ninja、pkg-config、GTK 开发库、libsecret 开发库与可用的系统 Secret Service。

```sh
flutter build windows
flutter build linux
```

## 真实社区联调

取得社区书面许可后，由站方配置 Discourse User API 授权，使用用户级密钥，禁止使用管理员 API Key。

```sh
flutter run --dart-define=COMMUNITY_ACCESS_ENABLED=true
```

在设置中填入对应 User API Key 与 Client ID。当前接口使用 `read/write` 能力，具体 scope 与站方限制需联调确认；客户端没有实现 jAccount 密码登录或自动生成密钥授权。密钥仅存于系统安全存储；退出会清除本机凭据，不代表服务器端吊销，应在站点授权设置中进一步撤销。

未经许可的默认离线构建无法连接站点，演示内容不来源于社区。书面许可要求参考 https://shuiyuan.sjtu.edu.cn/tos 。
