# 星账桌面端：Windows + macOS

当前公开测试版：0.9.0+12，[GitHub Release](https://github.com/southkite2023/quota-hub/releases/tag/v0.9.0)。桌面账户需要在桌面端重新配置，不自动同步手机凭据。

## 使用

1. 打开 Astracct，进入“管理 / 添加余额账户”，选择余额种类、服务商和账户信息，验证后保存。
2. 勾选“显示在悬浮窗”；主界面仍显示全部账户。可以多选账户，每个币种独立展示，不求和。
3. 点击“打开余额悬浮窗”，应用切为可拖动、默认置顶的紧凑窗口。拖动标题“星账”移动窗口；图钉切换置顶，眼睛切换金额隐藏，刷新按钮查询。
4. 点击“返回主界面”或按 Esc 恢复主窗口，在账户设置中修改选择；隐藏状态在模式切换时保留。
5. 关闭悬浮窗会退出应用；运行期间切换到其他程序仍按设置刷新。退出、睡眠或网络受限会停止或延迟查询，不提供系统常驻服务、托盘或自启动。

第一次查询失败会显示错误和未知余额；已有成功值失败后标记过期。OpenAI 显示本月费用而非剩余余额；服务商支持范围与 Android 共用适配器，实验性接口仍需真实凭据验证。

## 安全存储与平台配置

使用固定版本 window_manager 0.5.2 与 flutter_secure_storage 11.2.0。macOS 使用应用专属 service 的非共享 legacy Keychain（usesDataProtectionKeychain=false），避免启用需 provisioning 的 Keychain Sharing；Windows 使用插件的系统安全存储。凭据不写进余额快照、悬浮窗或构建配置。

Android 仍使用原有 Keystore 库，不改变包名、证书或存储格式。桌面独立账户库沿用 version 1 格式和 widgetAccountIds 字段保存多选，界面命名为悬浮窗。

生成 runner 后必须运行 scripts/configure-desktop-runners.py，固定 macOS bundle ID 为 com.yuashie.astracct，并给 Debug/Release sandbox 增加出站网络权限；Windows 可执行文件为 astracct.exe。公开 macOS 签名、公证和 Windows 安装器未配置，候选包不作为商店或公证发行版。

## 核验状态

新增回归覆盖：安全存储接口往返、多选与重启恢复、隐私切换、空选择、币种与过期零值、桌面刷新设置、最小窗口尺寸、置顶失败和切换回滚。

CI 构建生产客户端并另行构建原生冒烟入口，在 Windows/macOS 运行窗口缩小、置顶/取消、恢复和安全存储写入/读取/删除检查；冒烟只使用合成数据、不查询真实 API，不作为分发包。

本轮源码 head `1843ef382cb3a616443c54421618fbdb03707f1a`，通过 [PR #14](https://github.com/southkite2023/quota-hub/pull/14) 合入 main，合并 `f05c065eda496165af5b9e52c8c7ec2230c4c391`。CI 检出 `8cf099a561111d821312ec2a41b500cfa6e656e5` 与主线合并树相同（`802a705fa20e20262986e483047d6dac7df776be`）。

- [客户端验证 37734459611](https://github.com/southkite2023/quota-hub/actions/runs/37734459611)：94/94 Flutter 测试、静态检查和 Web 构建通过。
- [原生验证 37734459516](https://github.com/southkite2023/quota-hub/actions/runs/37734459516)：Windows Release、macOS Release、iOS 模拟器及 Android Release AOT 构建通过；Windows/macOS 两平台原生窗口和系统安全存储冒烟检查通过，均使用合成数据，不使用真实 API 凭据。
- 本地合约/服务端 17/17 测试、资产同步检查和 runner 配置重复运行检查通过（保留 sandbox、稳定身份与出站权限）。
- Windows 生产候选产物 `11531018234`，macOS 生产候选产物 `11530854902`；生产包在构建冒烟入口前已归档，避免把测试程序交给用户。包已下载保存，逐包重算摘要；Windows EXE 文件版本 0.9.0.12、运行库和 AOT 数据存在，macOS bundle 标识、0.9.0 / 12 版本及 9 个符号链接已核对。见 [下载包摘要](reports/0.9.0-desktop-packages.json)。
- Android +12 四种候选包固定证书校验通过，仍为 `com.yuashie.astracct` / 0.9.0 / versionCode 12；签名产物 `11530624437`，符号 `11531510597`。未重新生成密钥或修改旧账户库。

## 下载包使用

Windows：下载 ZIP 后完整解压，在同一目录运行 `astracct.exe`，保留 DLL 和 data 目录。

macOS：解压 ZIP 后打开 `Astracct.app`；此包未进行 Apple Developer 分发签名和公证，不宣称已经通过 Gatekeeper 或商店审核。

已在 GitHub Releases 公开发布桌面与 Android +12 测试包，个人网站项目 001 已部署对应的 v0.9.0 附件直链。Windows 为 x64，macOS 为 Intel + Apple Silicon Universal（macOS 12+）。

- [Windows 下载入口](https://yuashie.cn/projects/001/download?platform=Windows)
- [macOS 下载入口](https://yuashie.cn/projects/001/download?platform=macOS)
- [Android 下载入口](https://yuashie.cn/projects/001/download?platform=Android)

发布核验运行 `37738175470`；Netweb PR #5 合并 `04d393f10ccc513eb85ebf220b7c666c17f0704a`，部署运行 `37738371250` 成功且公网版本一致。候选清单保留原文件名用于追溯，公开文件名与校验值以 Release packages.json / SHA256SUMS.txt 为准。真实账户验证、人工拖动、跨显示器/DPI、长期刷新与用户机器安装尚待验收；不宣称已完成。
