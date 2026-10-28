# 星账 Astracct

Android / Windows / macOS 账户余额与费用查看工具：按账户独立查询，不把不同币种相加；支持前台刷新、可选后台刷新和桌面小组件。

当前 Android / Windows / macOS 公开版本为 [3.1.0+21 固定导航与完整余额仪表盘测试版](https://github.com/southkite2023/quota-hub/releases/tag/v3.1.0)。在「余额账户设置 → 应用更新」检查最新版本、查看说明、下载并确认安装，无需登录或白名单。旧版本需先从官网下载一次新版。

[个人网页下载](https://yuashie.cn/projects/001/download) 优先使用 Yuashie 服务器直下，GitHub Releases 保留备用安装包和更新日志。网页与应用共用按平台维护的 SHA-256 校验清单，服务器每十五分钟同步公开版本；iOS 使用 PWA，并在设置中提供检查和重新载入入口。Linux 暂无公开安装包。

Android 沿用 `com.yuashie.astracct` 与固定签名，安装由系统确认。Windows/macOS 在应用目录可写时备份旧程序、退出替换并重启；macOS 仍未配置 Apple 分发签名和公证。148 项 Flutter 测试、各端构建、桌面窗口与安全存储、临时目录中的实际升级和故障回退检查通过；真实服务商与厂商真机完整验收仍待完成。

## 3.1.0 固定导航与仪表盘

桌面导航在账户、设置及子页面间保持固定，切换页面保留未保存编辑。仪表盘完整显示已有指标，Mac 菜单栏显示项改为在数据行右侧勾选；一次显示一项，取消后只显示图标。原生三端构建和发布校验已通过。

## 3.0.0 新界面与本地凭据

`3.0.0+20` 已发布：桌面侧栏、手机底部导航、圆角卡片和统一浅深主题，包含此前开发候选的统一设置、应用锁、隐私与桌面行为。Mac 首次迁移钥匙串后使用本地明文文件（目录 0700、文件 0600），提供拖拽安装 DMG；同一系统用户的其他程序仍可能读取这些文件。详见 [本地凭据说明](docs/LOCAL_CREDENTIALS.md) 与 [通用设置说明](docs/GENERAL_SETTINGS.md)。

## 已有功能

- “余额账户”管理：AI 订阅、云服务器、节点订阅分类，多服务商和多账户；分类不代表相应平台所有订阅套餐均已适配。
- DeepSeek、OpenRouter、Kimi 国内站、阿里云、腾讯云等余额接口；OpenAI 查询组织本月费用，剩余余额显示未知；智谱为实验性余额接口。
- OneAPI 货币账单兼容接口，以及自定义 HTTPS GET + Bearer + JSON 数值余额接口。
- 凭据在 Android 本机加密保存；余额按账户和币种展示，区分零、未知、查询失败及过期缓存。
- 首页显示全部账户；小组件可选择部分账户并点击打开。自动刷新受 Android 和厂商后台限制。

## 功能边界

Android 支持桌面小组件与可选后台服务；Windows/macOS 新增真实账户管理与悬浮余额模式，桌面验证见 [使用与验证说明](docs/DESKTOP.md)。Web/iOS 仍保留演示/自托管路径。真实服务商账户、厂商真机、凭据覆盖迁移、桌面小组件与长期后台刷新仍需验收。

1.3.0 包含自 1.1.0 起新增的基于 HTTPS 订阅响应头 `subscription-userinfo` / `x-subscription-userinfo` 的节点流量、到期日查询（仅支持实际返回标准响应头的服务商；不解析订阅正文）。iOS PWA 可能因跨域响应头限制而不可用。AI 类别不等于会员或 Coding 配额查询；硅基流动暂未接入。不要把演示数据或费用当作可用余额。详见 [服务商说明](docs/PROVIDERS.md)。

## 开发与发布

- [客户端配置与开发](apps/client/README.md)
- [Android 发布与下载](docs/RELEASING.md)
- [个人网页下载与发布说明](docs/FIRST_PUBLIC_RELEASE.md)
- [版本规则](docs/VERSIONING.md) 与 [更新日志](CHANGELOG.md)
- [架构](docs/ARCHITECTURE.md)、[数据协议](packages/contracts/README.md) 与 [可选服务端](apps/server/README.md)

构建使用 Flutter 3.47.5 和提交的依赖锁。Android Release 输出通用及按 ABI 拆分的包，公开分发必须校验固定签名、版本和 SHA-256。构建模式为 Release 不表示已经通过商店审核。

## 贡献与安全

请阅读 [贡献说明](CONTRIBUTING.md) 和 [安全说明](SECURITY.md)。不要提交真实 API Key、云密钥、订阅链接或个人账单截图。开源代码采用 [MIT](LICENSE) 许可；商店主体、版权与备案材料仍需按实际情况办理。
