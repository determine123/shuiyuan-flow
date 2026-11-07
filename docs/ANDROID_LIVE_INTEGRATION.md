# Android 真实社区联调准备

2026-11-07：用户确认尚未取得社区书面许可。尚未向真实社区执行客户端登录、读取帖子、发帖或点赞联调；默认离线构建开关保持关闭。ADB 当前无连接设备。

## 给站方确认的事项

1. 是否书面许可“源流 / Shuiyuan Flow”第三方客户端接入；许可覆盖的版本、测试账号、访问范围和测试时段。
2. 是否允许 Discourse User API 授权，以及测试账号所在组是否可以创建 User API Key。
3. 允许的 scopes：首轮仅确认读取与当前用户识别所需权限，特别核对 `read`、`session_info`；发帖、回复、点赞相关 `write` 等权限另行核对。不可假定只给 `read/write` 就覆盖所有接口。
4. 客户端标识约定、请求频率和可测试的分类/话题；是否提供测试站及指定的可写测试话题。
5. 后续浏览器授权需要允许的回调地址。当前客户端只有手动输入用户级密钥的入口，尚未实现密钥对、nonce 校验及授权回调，不能把这一入口称为完整登录流程。

Client ID 在 Discourse 协议中是客户端唯一标识，不一定由站方发放；具体约定与站方确认。禁止使用管理员 API Key，用户密码、Cookie 和 API Key 均不应发到聊天或提交仓库。

## 取得许可后的执行顺序

1. 确认书面许可范围和站方配置，准备测试手机或模拟器。模拟器可以验证接口功能，不能用于真机 Profile 性能结论。
2. 在隔离构建目录启用 `--dart-define=COMMUNITY_ACCESS_ENABLED=true`，生成单独命名的联调 APK，不覆盖当前离线分发包。安装前检查签名与现有用户数据，避免自动卸载。
3. 用户在设备端填写站方认可的用户级密钥和对应 Client ID。先验证 `/session/current.json`，随后检查分类、最新列表、搜索、话题及分页楼层。
4. 验证密钥无效/撤销、401/403、限流与断网恢复，以及演示/真实账号本地数据隔离。不把响应正文或凭据写入测试报告。
5. 仅在明确授权的测试区域验证写操作，避免在普通社区话题发布测试内容。当前没有写操作测试授权。
6. 退出后检查本机凭据清除，并由用户在站点应用授权设置撤销测试密钥。记录设备、构建、接口状态码与结果；只有实际执行成功后才标记通过。

## 当前代码与证据

- 开关：`lib/forum_api.dart` 的 `COMMUNITY_ACCESS_ENABLED` 默认 false。
- API：`DiscourseRepository` 使用 User API 请求头，禁止跟随 HTTP 跳转，处理授权错误、限流、超时及非 JSON 返回。
- 凭据：`lib/app_state.dart` 使用系统安全存储，默认离线时不恢复真实会话。
- `test/api_test.dart` 使用本地 Mock HTTP；通过此测试不代表真实水源接口已兼容。

参考：[水源社区协议](https://shuiyuan.sjtu.edu.cn/tos)、[Discourse User API 规范](https://meta.discourse.org/t/user-api-keys-specification/48536)。
