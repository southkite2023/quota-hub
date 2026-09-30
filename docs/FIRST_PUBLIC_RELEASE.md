# 个人网页下载与发布说明

2026-09-30：分发方向改为个人网页下载，不向国内应用商店提交。App 当前为 0.7.1 精简测试版，安装包托管在 GitHub Releases；Netweb 的 `/projects/001` 页面负责展示下载入口。

## 下载地址

- [ARM64 · 17.02 MB](https://github.com/southkite2023/quota-hub/releases/download/v0.7.1/quota-hub-0.7.1-arm64-v8a.apk)：64 位 ARM 安卓手机。
- [通用包 · 48.80 MB](https://github.com/southkite2023/quota-hub/releases/download/v0.7.1/quota-hub-0.7.1-universal.apk)：不确定架构时使用。
- [32 位 ARM · 14.25 MB](https://github.com/southkite2023/quota-hub/releases/download/v0.7.1/quota-hub-0.7.1-armeabi-v7a.apk)：仅支持 32 位 ARM 的旧设备。
- [发布说明和校验文件](https://github.com/southkite2023/quota-hub/releases/tag/v0.7.1)。

网页主下载按钮指向 ARM64 的固定版本链接，附近标明版本、架构和大小；保留原 GitHub 项目按钮。以后发布新版时同步修改网页数据，不能只改版本文案而不改链接。GitHub 下载的网络可达性由用户环境决定；如需本站镜像，另行配置托管并核对同一 SHA-256。

## 已完成验证

原 Debug 通用 APK 为 150.87 MB。新 Release 通用包 48.80 MB（缩小 67.7%），ARM64 17.02 MB（缩小 88.7%）。使用 Release AOT、分离调试符号和按 ABI 分包，不删功能。详见 [包体报告](reports/0.7.1-apk-size.json)。

86 项 Flutter 测试、静态检查及各平台构建通过。所有 APK 的固定签名、版本、非调试标记、ABI、AOT 与 ZIP/64 位 ELF 16 KB 对齐检查通过。Android 15 x86_64 模拟器全新安装启动及从 0.7.0 无账户状态升级启动通过；没有使用真实凭据，不代表真实账户迁移、ARM 真机、小组件或长期后台刷新已验收。

## 后续维护

- 保留固定签名和包名，升级优先覆盖安装；卸载会删除本机账户配置。更换包名属于独立迁移，不能当作普通覆盖更新。
- 凭据查询与本机存储行为应有准确的用户说明和联系方式。个人网页分发不改变应用实际数据处理行为；不把商店材料清单当作当前发布流程，也不据此作监管豁免承诺。
- 保留“测试版”标识和功能边界：节点订阅目前仅自定义余额接口；AI 类别不是会员套餐查询；OpenAI 是费用而非可用余额。
- 测试真实账户迁移、厂商手机、小组件、通知拒绝、后台停止与省电限制；不承诺后台全天候精确定时更新。
- 每个分发版本递增构建号，归档校验文件和匹配符号。0.7.1 符号已备份在被 Git 忽略的 `private/release-symbols/0.7.1/symbols.zip`，SHA-256：`00872b5668f2a2f6d57081e1f59ed1c6ffaf1cbb8697ddc7f7050ba25574b9ad`。
