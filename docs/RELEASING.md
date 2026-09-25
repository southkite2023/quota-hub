# Android 安装包分发

用户指定 GitHub Releases 为安装包下载入口。当前版本：[0.3.0 测试版](https://github.com/southkite2023/quota-hub/releases/tag/v0.3.0)。

- [最新版本及更新日志](https://github.com/southkite2023/quota-hub/releases/latest)
- [0.3.0 APK 直接下载](https://github.com/southkite2023/quota-hub/releases/download/v0.3.0/quota-hub-0.3.0-android.apk)

## 每次发布

1. 按 `VERSIONING.md` 判断版本递增并维护 `CHANGELOG.md`。同一版本仅调整分发入口不递增版本。
2. 确认源码提交、客户端测试及 Android 构建成功，校验产物来源和 APK 内的版本名、构建号。不要把旧包改名冒充新版本。
3. 标签 `vX.Y.Z` 指向 APK 对应源码提交。先创建 Release 草稿，上传 `quota-hub-X.Y.Z-android.apk` 与 `SHA256SUMS.txt`，再发布。不要覆盖已经公开的版本或附件。
4. Release 说明记录实际更新、测试结果、已知限制与构建来源；测试构建须在标题及正文标注，不能宣称完成正式验收。
5. 按用户要求将当前公开下载版本设为 Latest，使仓库右侧可访问，并核对 `/releases/latest` 及 APK 附件。Latest 表示下载入口的最新版本，不代替质量验收。
6. 更新日志中的下载入口改用 Releases。Actions artifact 仅用于构建溯源，其保留期不作为用户下载期限。

## 当前包

0.3.0+4 使用已经通过验证的 Debug APK，源码为 `3f40723ef07060a363a7b34535f899239522b440`，来自原生构建 `36052195648`。未重新打包或更换签名。真实账户及 Android 真机验收仍待完成。

本次发布使用的一次性工作流已在成功后移除，避免以后更新 PR 时意外重复发布。以后按上述流程发布对应版本。
