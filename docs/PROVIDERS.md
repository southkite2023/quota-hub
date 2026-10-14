# API 余额平台接入

核对日期：2026-09-29。优先级来自用户：DeepSeek > 硅基流动 > OpenRouter > 阿里云百炼 > OneAPI 兼容接口 > 智谱/Kimi > OpenAI。

| 平台 | 此版本状态 | 余额语义与接入条件 |
| --- | --- | --- |
| DeepSeek | 已实现适配，真机待验收 | 官方 API Key；`GET /user/balance`；各币种的可用、赠送、充值余额 |
| 硅基流动 | 暂停旧接口接入 | 官方公告旧 `/user/info` 于 2026-08-14 停用；尚未确认替代接口，不继续请求旧接口 |
| OpenRouter | 已实现适配，真机待验收 | Management Key；`GET /api/v1/credits`；购买额度减去已用额度，USD；不是单 Key 限额 |
| 阿里云 / 百炼费用账户 | 已实现云账户查询，真机待验收 | RAM AccessKey 签名调用 BSS `QueryAccountBalance`；整个费用账户的可用额度及现金余额，百炼专属额度未实现 |
| 腾讯云 | 已实现中国站查询，真机待验收 | CAM SecretId / SecretKey 签名调用 `DescribeAccountBalance`；分转换为 CNY 元 |
| OneAPI 兼容接口 | 已实现有限兼容，站点待验收 | HTTPS 站点根地址或 /v1 地址、API Key、用户确认的币种；核对货币计费模式后读取兼容 subscription 与 usage；usage 除以 100。站点可能返回账户额度或令牌额度，不混称账户余额。无限额度显示余额未知 |
| 智谱 | 已实现实验性适配，API Key 接受情况未验证 | 按官方控制台脚本访问 `GET /api/biz/account/query-customer-account-report`，原样 Authorization；只接受成功码 200 和 `data.availableBalance`；不是公开稳定 API，不支持 Coding 配额 |
| Kimi（国内站） | 已实现适配，真实账户待验收 | 国内开放平台 API Key；`GET https://api.moonshot.cn/v1/users/me/balance`；分别显示人民币可用、代金券、现金余额；不支持 Coding 和国际站 Key |
| OpenAI | 已实现费用查询，余额未知；真实账户待验收 | 组织 Admin API Key；`GET /v1/organization/costs`；UTC 本月截至查询时刻的 USD 费用，完整处理分页；余额固定显示未知 |
| 自定义 | 已实现有限格式 | HTTPS GET + Authorization Bearer，JSON 字段路径（如 `data.balance`）和币种；平台必须实际提供相应余额接口 |

## 节点订阅（1.1.0+15 开发候选）

- 「余额种类：节点订阅」可以选择「订阅链接 · 流量查询」，填写可信服务商提供的完整 HTTPS 订阅链接。链接可能带有查询参数令牌；只在本机加密账户配置中保存，确认弹窗仅显示主机名。无需另外填写 API Key。
- 客户端使用 GET，请求不跟随 30x 跳转，不下载或解析订阅正文，不把节点/代理服务器信息持久化。解析 `subscription-userinfo` 或 `x-subscription-userinfo` 头中的 `upload`、`download`、`total`（字节）和可选 `expire`（Unix 秒）。剩余流量按 `max(total-upload-download,0)` 计算；过期时间缺失或为 0 显示未知。
- 响应头缺失、HTTP 错误、字段异常时明确失败，不将流量解释为货币或假定为零；刷新失败保持先前快照并标注过期。
- 并非所有 VPN/机场都暴露此协议：只返回订阅正文、需要 Cookie/登录会话、使用供应商私有 API 的订阅暂不支持；没有统一的人民币账户余额接口。Flutter Web/iOS PWA 读取自定义响应头还受到 CORS/Access-Control-Expose-Headers 限制，尚未实现受信任的后端代理。
- 本功能为尚未发布、尚未通过真实订阅及设备验收的开发候选。不要将真实链接、Token 或节点配置粘贴进公开 Issue、聊天或日志。

## 依据

- [DeepSeek 余额](https://api-docs.deepseek.com/zh-cn/api/get-user-balance/)
- [硅基流动更新公告：2026-08-11 接口停用通知](https://docs.siliconflow.cn/docs/release-notes/overview)
- [OpenRouter credits：需要 Management Key](https://openrouter.ai/docs/api/api-reference/credits/get-credits)
- [阿里云 QueryAccountBalance](https://help.aliyun.com/zh/user-center/developer-reference/api-bssopenapi-2017-12-14-queryaccountbalance)
- [OneAPI 账单实现](https://github.com/songquanpeng/one-api/blob/main/controller/billing.go) 和 [状态字段](https://github.com/songquanpeng/one-api/blob/main/controller/misc.go)
- [Kimi 官方余额接口](https://platform.kimi.com/docs/api/balance)
- [OpenAI Usage / Costs](https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage)

未确认不表示平台绝对没有接口，只表示当前版本没有经过核实并实现的适配器。模型调用兼容性不等于账单兼容性。

## 验收要求

单元/界面测试覆盖请求地址与认证、金额转换、无穷额度、错误隔离、多账户保存删除、组件选取和旧账户记录兼容。实际平台凭据、Android 加密存储升级、桌面组件与设备重启行为仍需真机验收。Key 仅在应用中输入，不提交到仓库或聊天。

## 0.3.0 云平台补充

现已实现阿里云和腾讯云中国站的账户余额适配；百炼费用账户查询由阿里云入口承接，百炼独立模型额度仍未实现。配置方法、接口范围及限制见 [云账户接入](CLOUD_PROVIDERS.md)。

## 0.6.0 本轮核实与限制

- 硅基流动：2026-09-29 再次核对官方更新公告，仍载明旧 `/user/info` 于 2026-08-14 停用，替代接口另行公告。旧 GitHub OpenAPI 文件仍保留历史定义，与较新的停用公告不一致；补查当前公开目录仍未找到可核实的替代端点；本版本不恢复已停用端点，不收集此平台 Key。
- 智谱：公开文档目录未列出稳定的账户余额 API；继续检查[官方控制台](https://open.bigmodel.cn)所加载的[公开脚本](https://static.bigmodel.cn/wd-paas-front/js/app.71d74a7b.js)，确认 GET 路径、原样 Authorization、成功码与余额字段。无凭据访问该端点返回 HTTP 200、业务码 1001（未收到 Authorization）。据此加入实验性适配，但控制台使用的凭据可能不同于 API Key，尚未验证普通 API Key 可用性。只接受 code=200 和可解析的 availableBalance；可选显示 cashBalance、frozenBalance。不要填网页登录令牌，不支持组织/项目切换或 Coding 配额；鉴权失败需回官网查看。脚本是观察依据，不代表公开接口稳定性承诺。
- Kimi：严格检查成功码、状态和三个金额字段；保留官方返回的可用余额，不自行用现金与代金券相加（现金可为负数）。当前仅中国站 CNY。
- OpenAI：普通模型 Key 不能替代组织 Admin Key。费用可能存在平台入账延迟；本月至今按 UTC 定义，页面标注年月与统计口径。任何分页失败、分页循环、币种不符或金额缺失均视为失败，沿用带过期标记的旧快照，不展示部分合计。桌面组件仍显示余额未知，费用在应用内查看。
- OneAPI：根地址、尾部斜杠和 `/v1` API 地址均支持，保留子路径部署前缀；仍要求站点状态确认货币模式，不扩展声称兼容所有 New API 分支。
- 未提供真实平台凭据，本轮仅做模拟响应测试；不代表已通过真实账户或 Android 真机验收。
