# 系统设计草案

状态：提案，尚未实现。客户端框架仍需记录正式决策。

## 数据流

供应商 → 服务端采集器 → 标准快照和缓存 → 网页 / 独立 App / 原生小组件。

服务端负责认证、供应商凭据、查询限频和错误隔离。App 管理账户；小组件持独立、可撤销的只读令牌。首版每个自托管实例面向个人，多设备共享数据，不引入多人托管平台。

## 客户端与组件

| 平台 | 主程序候选 | 平台扩展 |
| --- | --- | --- |
| iOS | Flutter | SwiftUI / WidgetKit |
| Android | Flutter | Kotlin / Glance 或 AppWidget |
| macOS | Flutter | SwiftUI / WidgetKit、菜单栏 |
| Windows | Flutter | Windows App SDK Widget Provider、托盘 |
| Web | Flutter Web | 浏览器看板 |

Flutter 主界面采用自己的绘制系统；平台原生组件单独编写。若要求主界面也全部采用系统控件，需改选 SwiftUI、Compose、WinUI 和独立网页。Windows 系统组件面板与桌面悬浮窗口分别规划。

Apple 扩展通过 App Groups 共享快照；其他系统使用相应安全存储与桥接。组件可按系统允许的时机使用只读接口获取数据，不依赖主 App 一直打开。点击组件通过深链接定位账户。最低系统版本、架构和打包方案在原型阶段验证。

## 首批适配器

- DeepSeek：官方 /user/balance，总余额、赠金和充值余额按币种保存。
- 通用订阅：优先读取 Subscription-Userinfo 的 upload、download、total、expire；不从设备流量推算套餐余额。不假定每个订阅都提供这些字段。
- 阿里云：QueryAccountBalance，区分现金余额与可用额度；ECS 实例到期属于后续单独适配。

## 数据规则

金额保存十进制字符串；不同币种不相加。流量以字节保存，明确 GB/GiB。缺失、零、无限额度分别表达。套餐到期不能当作流量重置日期。历史余额差不能直接作为消费，因为可能包含充值、退款和赠金。

快照包含版本、账户 ID、指标及单位、lastSuccessAt、过期和错误状态，不含供应商凭据。首次失败显示未知，后续失败保留旧数据并标记过期。

## 刷新和可靠性

服务端默认拟每 30 分钟采集，可按供应商调整；手动刷新限频并合并重复请求。每家独立超时和退避。App 启动先读缓存，再请求更新。系统组件后台刷新由系统调度，不承诺固定间隔。

## 凭据与网络

供应商凭据留在自托管服务端，不回传给客户端。云账户采用最小查询权限。小组件令牌按设备和账户范围控制，可撤销。日志隐藏完整订阅链接、密钥与原始响应中的秘密。

订阅 URL 查询限制协议、重定向、响应大小和超时；防止任意 URL 访问内部服务，内网源需显式配置。保持 TLS 验证。自托管主机必须能访问对应供应商；不默认保证任意地区的网络连通性。

## 实现与发布

建议服务端 TypeScript + SQLite，通过版本化 JSON / OpenAPI 与客户端共享契约；Docker Compose 提供自托管入口。仓库公开演示仅使用虚构样例。

每个目标分别验证安装、后台刷新、令牌撤销、深链接和离线状态。正式版本提供签名分发流程，不把开源源码等同于免签名安装或自动通过商店审核。

## 参考

- https://api-docs.deepseek.com/api/get-user-balance/
- https://help.aliyun.com/en/user-center/developer-reference/api-queryaccountbalance
- https://docs.flutter.dev/reference/supported-platforms
- https://docs.flutter.dev/resources/architectural-overview
- https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- https://developer.android.com/develop/ui/compose/glance
- https://learn.microsoft.com/en-us/windows/apps/develop/widgets/widget-providers
