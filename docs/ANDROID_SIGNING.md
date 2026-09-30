# 固定 Android 签名

0.5.0 起的公开 APK 必须使用固定的 `quota-hub` 签名密钥，证书 SHA-256 记录于 `ANDROID_SIGNING_SHA256.txt`。缺少密钥或证书不一致时应停止发布，不能退回随机调试签名。

密钥已在本机生成，保存在仓库内被 Git 忽略的 `private/android-signing/`。该目录包含 PKCS#12 密钥库、密码文件和公开证书；应完整备份到用户的加密离线存储。不要提交或发到聊天。

在本机终端执行 `./scripts/configure-android-signing.sh`，登录 GitHub 后会通过标准输入将密钥和密码加密保存为仓库 Actions Secrets：`ANDROID_SIGNING_STORE_BASE64` 与 `ANDROID_SIGNING_PASSWORD`，不会在终端打印其内容。

也可不安装 Homebrew 或 GitHub CLI：打开仓库 Settings → Secrets and variables → Actions，分别新增上述两个 Repository secrets。`ANDROID_SIGNING_STORE_BASE64` 填密钥库的 Base64 内容，`ANDROID_SIGNING_PASSWORD` 填密码文件内容。只粘贴到 GitHub Secret 输入框，不要发送到聊天或提交到仓库；配置后清空剪贴板。保存 Secrets 不会自动发布安装包，需重新运行 Android 构建验证签名。

CI 运行 `scripts/sign-android-apk.sh input.apk output.apk`，用这两个环境变量签名并校验证书指纹。Android 对外应用包名（applicationId）自下一版本起固定为 `com.yuashie.astracct`，后续递增构建号。固定签名证书保持不变；以后所有公开测试版与正式版都继续使用此固定密钥，CI 的临时调试产物不能上传到 Releases。

包名迁移说明（2026-09-30）：`0.5.0`–`0.7.1` 的公开 APK 使用旧包名 `com.example.quota_hub`。改为 `com.yuashie.astracct` 后，Android 将其视为新的应用身份，即使签名证书相同也不能覆盖安装旧包；用户需要卸载旧包并重新安装，新包后续版本再以 `com.yuashie.astracct` + 当前固定证书作为连续升级基线。

0.3.0、0.4.0 原有调试私钥未保留，无法用新密钥为旧安装提供兼容更新。第一次迁移仍需用户自行保留配置和凭据后重装；从第一份固定签名 APK 开始，后续版本才能覆盖更新、保留本机数据。

当前状态（2026-09-29）：用户已通过网页配置 Secrets，工作流 `36505744396` 的签名、证书指纹校验及产物上传全部通过；固定签名产物 ID 为 `11006558231`，源码为 `fc31f95ae44d26fff8388654a9f47fbc69fc1738`。新版工具输出带 `V3.0 Signer` 前缀，脚本已兼容。密钥保持原样，无需重新生成。用户随后授权发布，0.5.0 已于 2026-09-29 发布到 Releases 并设为 Latest；真机覆盖更新仍待验收。

0.6.0 发布记录（2026-09-29）：源码 `9894a53d8aa6e90ab85b05ee2095b678f17c44d3`，原生运行 `36529877814` 的固定签名产物 `11016217201` 校验通过；发布运行 `36530347847` 再次验证证书与 APK 版本 `0.6.0+7` 后公开发布。证书与 0.5.0 相同，真机覆盖更新待验收。

0.7.0 发布记录（2026-09-30）：源码 `7e231e8339f4702f38461605016784969de9fef8`，原生运行 `36680847428` 的固定签名产物 `11081587882` 校验通过；发布运行 `36681375368` 再次验证证书与 APK 版本 `0.7.0+8` 后公开发布。证书与 0.5.0/0.6.0 相同，真机覆盖更新待验收。
