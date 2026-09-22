# Quota Hub · 余量看板

开源、自托管的跨平台余额与用量管理项目，计划覆盖 Web、Android、iOS、macOS 和 Windows，并提供基于独立 App 的系统原生小组件。

> 当前阶段：项目规划。尚无可运行 App、安装包或可部署服务。下面均为计划能力。

## 目标

- 在一个地方查看 API 余额、代理订阅流量和云账户余额。
- 首批适配 DeepSeek、通用订阅流量信息与阿里云。
- 独立 App 搭配 iOS/macOS WidgetKit、Android AppWidget/Glance 和 Windows Widget Provider。
- 自托管服务统一采集；设备只读组件访问与供应商凭据隔离。
- 显示最后更新时间，正确区分零余额、未知、查询失败和过期缓存。

## 从哪里开始

阅读 [开发步骤](docs/GETTING_STARTED.md) 、[路线图](docs/ROADMAP.md) 和 [系统设计](docs/ARCHITECTURE.md)。首先完成数据协议与模拟快照，再验证跨平台 App 和原生组件桥接。

## 技术方向（待验证）

- 客户端候选：Flutter。独立安装，主界面由 Flutter 绘制；系统小组件采用平台原生技术。
- 服务端候选：TypeScript、SQLite、Docker Compose。
- 数据契约：版本化 JSON / OpenAPI；金额使用十进制字符串，流量保存字节数。
- 如主界面要求全平台原生控件，则在框架决策阶段调整客户端路线。

## 计划目录

```text
apps/client/           # 五端客户端及原生扩展（待创建）
services/api/          # 采集、认证、快照（待创建）
packages/contracts/   # 数据协议与模拟数据（待创建）
docs/                 # 设计、开发与发布文档
```

## 状态与边界

三家真实账户尚未完成接口联调。订阅不一定提供流量重置日期；Windows 系统组件面板与桌面悬浮窗口是不同功能；系统后台刷新不保证精确间隔。五端应分别通过构建和真机/系统验收后才标记支持。

## 贡献与安全

请先阅读 [贡献说明](CONTRIBUTING.md) 和 [安全说明](SECURITY.md)。不要提交真实密钥、订阅链接、账单或账户截图。

## License

[MIT](LICENSE)
