# Flutter 客户端原型

此目录为模拟快照驱动的最小主界面。三张账户卡片与状态切换通过 GitHub Actions 的 Web、Android、Windows、macOS、iOS 模拟器构建；设备安装、实际显示与原生小组件尚未验收。Android 支持在应用中设置自己的 DeepSeek API Key 并直接查询官方余额接口；未配置时不显示虚构的 DeepSeek 余额。其余平台仍保留原有演示/自托管查询路径。

在安装 Flutter SDK 的环境中，从 `apps/client` 运行：

```sh
flutter create --platforms=web .
flutter pub get
flutter run -d chrome
```

要生成其他平台工程，进入同一目录执行 `flutter create --platforms=android,ios,macos,windows .`，然后逐个平台构建、安装和记录结果。iOS/macOS 需要 macOS 与 Xcode，Windows 需要 Windows 与 C++ 构建环境。

[原生构建记录与演示产物](https://github.com/southkite2023/quota-hub/actions/runs/35729527097)：Android 调试 APK 与 Windows 程序目录位于 Artifacts，保存至 2026-09-29。下载 Windows 压缩包后需完整解压，保持 DLL 和 data 目录与可执行文件在一起；Android 调试 APK 仅用于自行安装测试。iOS 模拟器构建不是可安装在 iPhone 上的 IPA。

## Android 桌面组件原型

Android runner 中加入了一个 AppWidget。安装新的调试 APK 后先打开 App 一次，组件会从 App 接收版本 1 模拟快照并显示 DeepSeek 可用余额；未打开前显示“打开应用加载数据”。组件中的零值显示为 `0 CNY`，过期缓存保留上次成功值并标出过期。点组件会打开 App 并高亮相应账户。App 切换“过期缓存”场景或切换“隐藏金额”时会向组件推送相同状态。快照和隐藏设置保存在应用私有存储中，内容仅为虚构数据。

在 Android 桌面长按空白处，进入“小组件”，找到 Quota Hub 并添加。安装、桌面显示、点击跳转仍需在真实设备上验收；构建成功本身不代表这些行为已验证。这个组件没有后台网络刷新，也没有账户选择设置。

`assets/cases.json` 是 `packages/contracts/fixtures/cases.json` 的镜像。更新协议样例后运行仓库根目录的 `node scripts/sync-client-fixtures.mjs`，提交更新后的资产；CI 会检查两份文件一致。

## 非 Android 平台的旧自托管测试方式

先按 [服务端说明](../server/README.md) 配置自托管服务和 HTTPS。编译自己的测试版本时设置 `QUOTA_HUB_URL`（不带末尾斜杠）与服务端单独生成的 `QUOTA_HUB_READ_TOKEN`，例如 `flutter run -d android --dart-define=QUOTA_HUB_URL=https://你的服务域名 --dart-define=QUOTA_HUB_READ_TOKEN=你的只读令牌`。应用启动和点击刷新时获取余额，并推送到 Android 桌面组件；另外两项仍为演示数据。查询失败会显示错误，不用演示余额冒充真实金额。

编译参数会保存在安装包中，可以被提取。此方式仅供你的个人测试，切勿公开发布含有私人只读令牌的 APK。切勿传入 DeepSeek API Key。当前公开的演示构建没有连接服务，也不包含任何令牌。


## Android：在应用中连接 DeepSeek

1. 安装此分支构建的 Android APK，点击首页“连接 DeepSeek”或右上角设置按钮。
2. 在 DeepSeek 开放平台创建自己的 API Key，在设置页粘贴后点击“验证并保存”。无需自建服务器或修改编译参数。
3. 验证成功后返回首页，显示每种币种的可用、赠送、充值余额和查询成功时间。刷新按钮重新查询；桌面组件显示优先 CNY 的第一种币种。
4. 更换 Key 时输入新的 Key；只有验证和本机保存均成功才切换账户。点击“移除本机账户与余额”可删除本机凭据与组件余额。

手机只向固定官方 HTTPS 地址 `https://api.deepseek.com/user/balance` 发送 Key；不跟随重定向、不调用模型、不在日志和快照中保存 Key。Key 由 Android Keystore 的 AES-GCM 密钥加密，密文存入 `noBackupFilesDir`，禁用应用备份及明文网络。用户自己的 Key 在安装后输入，不打包进 APK。卸载/清除应用数据后需重新配置。

首次查询失败显示错误；同一进程已有成功值时显示过期余额。重启后重新查询，不从磁盘恢复应用内余额。组件保存的是余额快照，不含 Key。尚无后台定时刷新或多 DeepSeek 账户选择。此实现适用于用户自行管理的个人 Key，不提供设备被攻破后的凭据保护保证。

测试：`flutter test` 验证官方请求、错误处理、多币种/零/负余额、替换/删除、保存失败和设置页交互。真实 Key 查询、重启后的加密存储读取、桌面组件及卸载行为仍需 Android 实机验收。


## Android 0.2：多平台、多账户

首页“管理 / 添加 API 账户”可以新增多个平台账户、修改名称与 Key、单独移除，以及选择桌面组件展示哪个账户。同一平台可配置多个 Key；余额不跨账户或币种求和。默认不再在 Android 首页混入订阅和阿里云演示卡片。

当前内置适配：DeepSeek、OpenRouter、OneAPI 兼容货币账单接口；另有自定义 HTTPS GET + Bearer + JSON 数值字段接入。服务商目录按用户优先级排列；硅基流动、阿里云百炼、智谱、Kimi、OpenAI 目前明确显示待适配，不收集 Key、不发起请求。详见 [平台接入说明](../../docs/PROVIDERS.md)。

升级时读取旧版加密保存的 DeepSeek Key；首次账户设置变更会写入新的加密账户库并移除旧文件。即使新账户列表为空，也不会重新导入旧凭据。账号库读取失败时禁止覆盖保存，提示重试。每个账户独立处理刷新失败与旧值过期；改变平台/自定义地址需要重新输入 Key，避免把旧平台凭据发到新地址。

自定义平台与 OneAPI 验证前会显示目标地址并要求确认；不跟随重定向。自定义接口暂不支持 Cookie、签名认证、POST、任意请求头或公式，字段缺失不视为零。OneAPI 需开放 `/api/status`、`/v1/dashboard/billing/subscription` 和 `/v1/dashboard/billing/usage`，用户按站点选择币种。无法确认货币计费时拒绝查询；无限额度不转换为巨额余额。
