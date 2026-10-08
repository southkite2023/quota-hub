# Android 安装包分发

用户指定 GitHub Releases 为安装包下载入口。当前版本：0.8.0 Android 应用身份迁移测试版。

- [最新版本及更新日志](https://github.com/southkite2023/quota-hub/releases/latest)
- 0.8.0 发布后由 GitHub Releases 提供 ARM64、ARMv7、x86_64 与通用 APK。

## 每次发布

1. 按 `VERSIONING.md` 判断版本递增并维护 `CHANGELOG.md`。同一版本仅调整分发入口不递增版本。
2. 确认源码提交、客户端测试及 Android 构建成功，校验产物来源和 APK 内的版本名、构建号。不要把旧包改名冒充新版本。
3. APK 必须来自 `quota-hub-android-signed` 固定签名产物，并校验 `docs/ANDROID_SIGNING_SHA256.txt`；密钥缺失则停止发布，不得上传临时调试包。
4. 标签 `vX.Y.Z` 指向 APK 对应源码提交。先创建 Release 草稿，上传 `quota-hub-X.Y.Z-android.apk` 与 `SHA256SUMS.txt`，再发布。不要覆盖已经公开的版本或附件。
5. Release 说明记录实际更新、测试结果、已知限制与构建来源；测试构建须在标题及正文标注，不能宣称完成正式验收。
6. 按用户要求将当前公开下载版本设为 Latest，使仓库右侧可访问，并核对 `/releases/latest` 及 APK 附件。Latest 表示下载入口的最新版本，不代替质量验收。
7. 更新日志中的下载入口改用 Releases。Actions artifact 仅用于构建溯源，其保留期不作为用户下载期限。

## 0.7.0 历史包

0.7.0+8 为固定签名 Debug 测试 APK，源码 `7e231e8339f4702f38461605016784969de9fef8`，来自原生构建 `36680847428` 的 `quota-hub-android-signed`（产物 ID `11081587882`）。客户端运行 `36680847525` 的 86 项测试与静态检查、Web 构建通过，原生运行的 Android、Windows、macOS/iOS 模拟器构建通过。

发布运行 `36681375368` 校验产物 ZIP 摘要、APK 包名、版本和固定证书后，于 2026-09-30 发布并设为 Latest。APK SHA-256：`acd7b388788139c351a9cba641d0391a1a3d929efadf096b93ded26e00b2a60f`。Release 同时提供 `SHA256SUMS.txt`。

与 0.5.0/0.6.0 使用相同固定密钥，可尝试覆盖更新；真机安装、启动图标、覆盖更新、真实账户查询和后台刷新仍待验收。0.3.0/0.4.0 的旧调试签名不兼容；卸载会删除本机配置与凭据。

本次一次性发布工作流成功后移除，避免以后更新 PR 时意外重复发布。


## 历史包：0.7.1 精简测试版

[发布页](https://github.com/southkite2023/quota-hub/releases/tag/v0.7.1)，已公开并设为 Latest。个人网页提供下载按钮，GitHub Releases 托管安装包；不提交国内应用商店。提供通用、ARM64、ARMv7、x86_64 四种固定签名 Release APK、SHA256SUMS.txt 与 apk-report.json。

源码 `aea507ed01ea438315d49dae432fab1e46071a00`，构建 `36682873452`，固定签名产物 `11081779969`。四种包均为 0.7.1+9；签名、版本、非 Debug 标记、ABI、AOT 与 16 KB 二进制对齐已验证。运行 `36685735220` 完成 Android 15 x86_64 模拟器无账户状态升级和全新安装启动检查。

原草稿按用户选择由运行 `36686644580` 复核现有附件后公开，无重新构建或更换附件。ARM64 17.02 MB，通用 48.80 MB。仍为测试阶段，真实凭据迁移、厂商真机、小组件和长期后台行为待验收。

网页按钮使用固定版本直链，避免版本说明和安装包不一致；每次更新同时调整链接、大小和版本说明。详见 [个人网页分发说明](FIRST_PUBLIC_RELEASE.md)。


## 当前包：0.8.0 应用身份迁移测试版

Android applicationId 正式改为 `com.yuashie.astracct`，固定签名证书保持不变。由于包名变化，0.5.0–0.7.1 的 `com.example.quota_hub` 无法覆盖升级到 0.8.0；首次迁移需要卸载旧版并重新安装，之后以新包名和现有固定签名作为连续升级基线。

发布流水线仅在测试、静态检查、Release AOT 构建、固定签名和 APK 元数据校验全部通过后创建 GitHub Release，并上传四种 APK、SHA256SUMS.txt 与 apk-report.json。


## 0.9.0 开发候选（未公开发布）

主线已准备 0.9.0+11，88 项 Flutter 测试、静态检查和各端构建通过，已生成四种固定签名候选 APK。当前 Releases 与个人网站仍提供公开的 0.8.0。候选构建来源、哈希和未完成的真机验收见 [核验报告](reports/0.9.0-validation.md)。不得把候选产物称为已正式发布。
