# 固定 Android 签名

0.5.0 起的公开 APK 必须使用固定的 `quota-hub` 签名密钥，证书 SHA-256 记录于 `ANDROID_SIGNING_SHA256.txt`。缺少密钥或证书不一致时应停止发布，不能退回随机调试签名。

密钥已在本机生成，保存在仓库内被 Git 忽略的 `private/android-signing/`。该目录包含 PKCS#12 密钥库、密码文件和公开证书；应完整备份到用户的加密离线存储。不要提交或发到聊天。

在本机终端执行 `./scripts/configure-android-signing.sh`，登录 GitHub 后会通过标准输入将密钥和密码加密保存为仓库 Actions Secrets：`ANDROID_SIGNING_STORE_BASE64` 与 `ANDROID_SIGNING_PASSWORD`，不会在终端打印其内容。

也可不安装 Homebrew 或 GitHub CLI：打开仓库 Settings → Secrets and variables → Actions，分别新增上述两个 Repository secrets。`ANDROID_SIGNING_STORE_BASE64` 填密钥库的 Base64 内容，`ANDROID_SIGNING_PASSWORD` 填密码文件内容。只粘贴到 GitHub Secret 输入框，不要发送到聊天或提交到仓库；配置后清空剪贴板。保存 Secrets 不会自动发布安装包，需重新运行 Android 构建验证签名。

CI 运行 `scripts/sign-android-apk.sh input.apk output.apk`，用这两个环境变量签名并校验证书指纹。应用包名保持 `com.example.quota_hub`，后续递增构建号。以后所有公开测试版与正式版都使用此固定密钥；CI 的临时调试产物不能上传到 Releases。

0.3.0、0.4.0 原有调试私钥未保留，无法用新密钥为旧安装提供兼容更新。第一次迁移仍需用户自行保留配置和凭据后重装；从第一份固定签名 APK 开始，后续版本才能覆盖更新、保留本机数据。

当前状态（2026-09-29）：用户选择先完成代码、暂不发布安装包。密钥已生成，Secrets 配置与固定签名产物验证留到用户恢复发布时完成；无需重新生成密钥。
