# Android 安装包分发

用户指定 GitHub Releases 为安装包下载入口。当前版本：[0.5.0 测试版](https://github.com/southkite2023/quota-hub/releases/tag/v0.5.0)。

- [最新版本及更新日志](https://github.com/southkite2023/quota-hub/releases/latest)
- [0.5.0 APK 直接下载](https://github.com/southkite2023/quota-hub/releases/download/v0.5.0/quota-hub-0.5.0-android.apk)

## 每次发布

1. 按 `VERSIONING.md` 判断版本递增并维护 `CHANGELOG.md`。同一版本仅调整分发入口不递增版本。
2. 确认源码提交、客户端测试及 Android 构建成功，校验产物来源和 APK 内的版本名、构建号。不要把旧包改名冒充新版本。
3. APK 必须来自 `quota-hub-android-signed` 固定签名产物，并校验 `docs/ANDROID_SIGNING_SHA256.txt`；密钥缺失则停止发布，不得上传临时调试包。
4. 标签 `vX.Y.Z` 指向 APK 对应源码提交。先创建 Release 草稿，上传 `quota-hub-X.Y.Z-android.apk` 与 `SHA256SUMS.txt`，再发布。不要覆盖已经公开的版本或附件。
5. Release 说明记录实际更新、测试结果、已知限制与构建来源；测试构建须在标题及正文标注，不能宣称完成正式验收。
6. 按用户要求将当前公开下载版本设为 Latest，使仓库右侧可访问，并核对 `/releases/latest` 及 APK 附件。Latest 表示下载入口的最新版本，不代替质量验收。
7. 更新日志中的下载入口改用 Releases。Actions artifact 仅用于构建溯源，其保留期不作为用户下载期限。

## 当前包

0.5.0+6 为固定签名的 Debug 测试 APK，源码 `fc31f95ae44d26fff8388654a9f47fbc69fc1738`，来自原生构建 `36505744396` 的 `quota-hub-android-signed`（产物 ID `11006558231`）。发布工作流 `36506563622` 校验产物 ZIP 摘要、APK 包名与版本、固定证书指纹后，于 2026-09-29 发布并设为 Latest，未重新构建。

APK SHA-256：`389a096212483bd9f6d4dec984073e6fccc7e45456864890110af1424dfcb74b`。Release 同时提供 `SHA256SUMS.txt`。

旧版 0.3.0/0.4.0 临时调试私钥未保留，首次迁移不能覆盖安装；请自行保留配置和凭据后卸载旧版、重装本版，卸载会删除本机数据。以后公开版本沿用固定密钥。真机显示、组件滚动、覆盖更新及长时间后台刷新仍待验收。

本次一次性发布工作流在成功后移除，避免以后更新 PR 时意外重复发布。
