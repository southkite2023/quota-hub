# Flutter 客户端原型

此目录为模拟快照驱动的最小主界面。三张账户卡片与状态切换通过 GitHub Actions 的 Web、Android、Windows、macOS、iOS 模拟器构建；设备安装、实际显示与原生小组件尚未验收。没有真实账号、密钥或网络请求。

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

## 私人测试：真实 DeepSeek 余额

先按 [服务端说明](../server/README.md) 配置自托管服务和 HTTPS。编译自己的测试版本时设置 `QUOTA_HUB_URL`（不带末尾斜杠）与服务端单独生成的 `QUOTA_HUB_READ_TOKEN`，例如 `flutter run -d android --dart-define=QUOTA_HUB_URL=https://你的服务域名 --dart-define=QUOTA_HUB_READ_TOKEN=你的只读令牌`。应用启动和点击刷新时获取余额，并推送到 Android 桌面组件；另外两项仍为演示数据。查询失败会显示错误，不用演示余额冒充真实金额。

编译参数会保存在安装包中，可以被提取。此方式仅供你的个人测试，切勿公开发布含有私人只读令牌的 APK。切勿传入 DeepSeek API Key。当前公开的演示构建没有连接服务，也不包含任何令牌。
