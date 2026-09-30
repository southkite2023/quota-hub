# Quota Hub · 余量看板

Android 账户余额与费用查看工具：按账户独立查询，不把不同币种相加；支持前台刷新、可选后台刷新和桌面小组件。

当前公开下载为 [0.7.0 测试版](https://github.com/southkite2023/quota-hub/releases/tag/v0.7.0)。[0.7.1 精简验证包草稿](https://github.com/southkite2023/quota-hub/releases/tag/untagged-a6832dd4cbd18d529ba1)已完成构建与模拟器基本安装启动检查，尚未公开发布或通过商店/厂商真机完整验收。草稿仅有仓库权限的用户可见。

## 已有功能

- “余额账户”管理：AI 订阅、云服务器、节点订阅分类，多服务商和多账户；分类不代表相应平台所有订阅套餐均已适配。
- DeepSeek、OpenRouter、Kimi 国内站、阿里云、腾讯云等余额接口；OpenAI 查询组织本月费用，剩余余额显示未知；智谱为实验性余额接口。
- OneAPI 货币账单兼容接口，以及自定义 HTTPS GET + Bearer + JSON 数值余额接口。
- 凭据在 Android 本机加密保存；余额按账户和币种展示，区分零、未知、查询失败及过期缓存。
- 首页显示全部账户；小组件可选择部分账户并点击打开。自动刷新受 Android 和厂商后台限制。

## 功能边界

Android 是当前重点验证平台。Web、Windows、macOS、iOS 可构建，但仍保留演示/自托管查询路径，不能视为与 Android 相同的完整产品。真实服务商账户、厂商真机、凭据覆盖迁移、桌面小组件与长期后台刷新仍需验收。

节点订阅目前不解析订阅链接、流量和到期日；AI 类别不等于会员或 Coding 配额查询；硅基流动暂未接入。不要把演示数据或费用当作可用余额。详见 [服务商说明](docs/PROVIDERS.md)。

## 开发与发布

- [客户端配置与开发](apps/client/README.md)
- [Android 发布与下载](docs/RELEASING.md)
- [首次国内商店发布准备](docs/FIRST_PUBLIC_RELEASE.md)
- [版本规则](docs/VERSIONING.md) 与 [更新日志](CHANGELOG.md)
- [架构](docs/ARCHITECTURE.md)、[数据协议](packages/contracts/README.md) 与 [可选服务端](apps/server/README.md)

构建使用 Flutter 3.47.5 和提交的依赖锁。Android Release 输出通用及按 ABI 拆分的包，公开分发必须校验固定签名、版本和 SHA-256。构建模式为 Release 不表示已经通过商店审核。

## 贡献与安全

请阅读 [贡献说明](CONTRIBUTING.md) 和 [安全说明](SECURITY.md)。不要提交真实 API Key、云密钥、订阅链接或个人账单截图。开源代码采用 [MIT](LICENSE) 许可；商店主体、版权与备案材料仍需按实际情况办理。
