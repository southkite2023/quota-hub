# API 余额平台接入

核对日期：2026-09-25。优先级来自用户：DeepSeek > 硅基流动 > OpenRouter > 阿里云百炼 > OneAPI 兼容接口 > 智谱/Kimi > OpenAI。

| 平台 | 此版本状态 | 余额语义与接入条件 |
| --- | --- | --- |
| DeepSeek | 已实现适配，真机待验收 | 官方 API Key；`GET /user/balance`；各币种的可用、赠送、充值余额 |
| 硅基流动 | 暂停旧接口接入 | 官方公告旧 `/user/info` 于 2026-08-14 停用；尚未确认替代接口，不继续请求旧接口 |
| OpenRouter | 已实现适配，真机待验收 | Management Key；`GET /api/v1/credits`；购买额度减去已用额度，USD；不是单 Key 限额 |
| 阿里云 / 百炼费用账户 | 已实现云账户查询，真机待验收 | RAM AccessKey 签名调用 BSS `QueryAccountBalance`；整个费用账户的可用额度及现金余额，百炼专属额度未实现 |
| 腾讯云 | 已实现中国站查询，真机待验收 | CAM SecretId / SecretKey 签名调用 `DescribeAccountBalance`；分转换为 CNY 元 |
| OneAPI 兼容接口 | 已实现有限兼容，站点待验收 | HTTPS 站点根地址、API Key、用户确认的币种；核对货币计费模式后读取兼容 subscription 与 usage；usage 除以 100。站点可能返回账户额度或令牌额度，不混称账户余额。无限额度显示余额未知 |
| 智谱 | 待核实/适配 | 尚未确认官方可用的现金余额接口，Coding 套餐额度不能冒充余额 |
| Kimi | 待核实/适配 | 尚未完成官方余额接口核实；Coding 套餐额度需另行适配 |
| OpenAI | 待适配 | 已核实的官方 Costs API 是费用统计，不能据此推算未提供的剩余余额 |
| 自定义 | 已实现有限格式 | HTTPS GET + Authorization Bearer，JSON 字段路径（如 `data.balance`）和币种；平台必须实际提供相应余额接口 |

## 依据

- [DeepSeek 余额](https://api-docs.deepseek.com/zh-cn/api/get-user-balance/)
- [硅基流动更新公告：2026-08-11 接口停用通知](https://docs.siliconflow.cn/docs/release-notes/overview)
- [OpenRouter credits：需要 Management Key](https://openrouter.ai/docs/api/api-reference/credits/get-credits)
- [阿里云 QueryAccountBalance](https://help.aliyun.com/zh/user-center/developer-reference/api-bssopenapi-2017-12-14-queryaccountbalance)
- [OneAPI 账单实现](https://github.com/songquanpeng/one-api/blob/main/controller/billing.go) 和 [状态字段](https://github.com/songquanpeng/one-api/blob/main/controller/misc.go)
- [OpenAI Usage / Costs](https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage)

未确认不表示平台绝对没有接口，只表示当前版本没有经过核实并实现的适配器。模型调用兼容性不等于账单兼容性。

## 验收要求

单元/界面测试覆盖请求地址与认证、金额转换、无穷额度、错误隔离、多账户保存删除、组件选取和旧账户记录兼容。实际平台凭据、Android 加密存储升级、桌面组件与设备重启行为仍需真机验收。Key 仅在应用中输入，不提交到仓库或聊天。

## 0.3.0 云平台补充

现已实现阿里云和腾讯云中国站的账户余额适配；百炼费用账户查询由阿里云入口承接，百炼独立模型额度仍未实现。配置方法、接口范围及限制见 [云账户接入](CLOUD_PROVIDERS.md)。
