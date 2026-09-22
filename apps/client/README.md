# Flutter 客户端原型

此目录为模拟快照驱动的最小主界面。三张账户卡片与状态切换可以在 Web 上验证；Android、iOS、macOS、Windows 的启动和原生小组件仍需各平台构建机验收。没有真实账号、密钥或网络请求。

在安装 Flutter SDK 的环境中，从 `apps/client` 运行：

```sh
flutter create --platforms=web .
flutter pub get
flutter run -d chrome
```

要生成其他平台工程，进入同一目录执行 `flutter create --platforms=android,ios,macos,windows .`，然后逐个平台构建、安装和记录结果。平台工程由 Flutter SDK 生成，不把未验证的生成物当作已支持平台。

`assets/cases.json` 是 `packages/contracts/fixtures/cases.json` 的镜像。更新协议样例后运行仓库根目录的 `node scripts/sync-client-fixtures.mjs`，提交更新后的资产；CI 会检查两份文件一致。
