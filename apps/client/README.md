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

`assets/cases.json` 是 `packages/contracts/fixtures/cases.json` 的镜像。更新协议样例后运行仓库根目录的 `node scripts/sync-client-fixtures.mjs`，提交更新后的资产；CI 会检查两份文件一致。
