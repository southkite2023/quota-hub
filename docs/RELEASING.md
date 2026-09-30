# Android 安装包分发

用户指定 GitHub Releases 为安装包下载入口。当前版本：[0.7.0 测试版](https://github.com/southkite2023/quota-hub/releases/tag/v0.7.0)。

- [最新版本及更新日志](https://github.com/southkite2023/quota-hub/releases/latest)
- [0.7.0 APK 直接下载](https://github.com/southkite2023/quota-hub/releases/download/v0.7.0/quota-hub-0.7.0-android.apk)

## 每次发布

1. 按 `VERSIONING.md` 判断版本递增并维护 `CHANGELOG.md`。同一版本仅调整分发入口不递增版本。
2. 确认源码提交、客户端测试及 Android 构建成功，校验产物来源和 APK 内的版本名、构建号。不要把旧包改名冒充新版本。
3. APK 必须来自 `quota-hub-android-signed` 固定签名产物，并校验 `docs/ANDROID_SIGNING_SHA256.txt`；密钥缺失则停止发布，不得上传临时调试包。
4. 标签 `vX.Y.Z` 指向 APK 对应源码提交。先创建 Release 草稿，上传 `quota-hub-X.Y.Z-android.apk` 与 `SHA256SUMS.txt`，再发布。不要覆盖已经公开的版本或附件。
5. Release 说明记录实际更新、测试结果、已知限制与构建来源；测试构建须在标题及正文标注，不能宣称完成正式验收。
6. 按用户要求将当前公开下载版本设为 Latest，使仓库右侧可访问，并核对 `/releases/latest` 及 APK 附件。Latest 表示下载入口的最新版本，不代替质量验收。
7. 更新日志中的下载入口改用 Releases。Actions artifact 仅用于构建溯源，其保留期不作为用户下载期限。

## 当前包

0.7.0+8 为固定签名 Debug 测试 APK，源码 `7e231e8339f4702f38461605016784969de9fef8`，来自原生构建 `36680847428` 的 `quota-hub-android-signed`（产物 ID `11081587882`）。客户端运行 `36680847525` 的 86 项测试与静态检查、Web 构建通过，原生运行的 Android、Windows、macOS/iOS 模拟器构建通过。

发布运行 `36681375368` 校验产物 ZIP 摘要、APK 包名、版本和固定证书后，于 2026-09-30 发布并设为 Latest。APK SHA-256：`acd7b388788139c351a9cba641d0391a1a3d929efadf096b93ded26e00b2a60f`。Release 同时提供 `SHA256SUMS.txt`。

与 0.5.0/0.6.0 使用相同固定密钥，可尝试覆盖更新；真机安装、启动图标、覆盖更新、真实账户查询和后台刷新仍待验收。0.3.0/0.4.0 的旧调试签名不兼容；卸载会删除本机配置与凭据。

本次一次性发布工作流成功后移除，避免以后更新 PR 时意外重复发布。


## 0.7.1 精简验证草稿（尚未公开）

[草稿入口](https://github.com/southkite2023/quota-hub/releases/tag/untagged-a6832dd4cbd18d529ba1)，需登录有仓库权限的 GitHub 账号查看，Latest 仍为 0.7.0。草稿包含通用、ARM64、ARMv7、x86_64 四种固定签名 Release APK、SHA256SUMS.txt 与 apk-report.json。

源码 `aea507ed01ea438315d49dae432fab1e46071a00`，构建 `36682873452`，固定签名产物 `11081779969`（ZIP SHA-256 `e5c0cc37356fe5ee17f69b298cfcd6c5b622b581ea418260c1d10963c134ab34`）。四种包版本均为 0.7.1+9；签名、元数据、非 Debug 标记、ABI、AOT 与 16 KB 二进制对齐已验证。

运行 `36685735220` 复核产物并完成 Android 15 x86_64 模拟器无账户状态升级和全新安装启动检查，创建草稿后保留未公开状态。此运行未重新构建 APK。下一步按 [首次商店发布清单](FIRST_PUBLIC_RELEASE.md) 完成隐私、资质和真机验收，再决定正式包名与发布版本。
