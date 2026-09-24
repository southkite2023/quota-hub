# 云账户余额（0.3.0 测试版）

在 Android 的“管理 / 添加余额账户”选择阿里云或腾讯云，填写账户名称和一组子账户密钥，点击“验证并保存”。查询成功后才替换已有配置。编辑时 Secret 不回填，保持密钥 ID 不变可留空保留原 Secret；更换密钥 ID 后需要重新输入 Secret。

## 阿里云中国站

使用 RAM 用户 AccessKey ID 和 AccessKey Secret。为该用户配置最小余额查询权限，官方接口列出的兼容授权如下：

```json
{"Version":"1","Statement":[{"Effect":"Allow","Action":["bss:DescribeAcccount"],"Resource":["*"]}]}
```

`DescribeAcccount` 的拼写与官方文档一致。只需要查询权限，不需要资源管理或购买权限。百炼的模型调用 API Key 不适用。

请求固定为 HTTPS `business.aliyuncs.com`，BSS API `2017-12-14` 的 `QueryAccountBalance`，使用 RPC HMAC-SHA1 签名。AccessKey Secret 不随网络请求发送；请求中包含 AccessKey ID 和签名，不记录完整请求 URL。可用额度可能包含信用额度，因此与现金余额分别显示。该查询返回整个阿里云费用账户，不是百炼独立余额。

参考：[余额接口](https://help.aliyun.com/en/user-center/developer-reference/api-bssopenapi-2017-12-14-queryaccountbalance)、[签名](https://help.aliyun.com/zh/user-center/developer-reference/signature)、[服务地址](https://help.aliyun.com/zh/user-center/developer-reference/request-structure)。

## 腾讯云中国站

使用 CAM 子用户 SecretId 和 SecretKey，在腾讯云访问管理中为其授予费用中心 `DescribeAccountBalance` 查询权限。不要使用只有模型调用权限的 Key。

请求固定为 HTTPS `billing.tencentcloudapi.com`，版本 `2018-07-09`，POST `{}`，TC3-HMAC-SHA256 签名。`RealBalance` 为可用余额；现金、赠送金额分别展示，所有这些字段按分转换成人民币元。信用额度不叠加到可用余额。

参考：[余额接口](https://cloud.tencent.com/document/api/555/20253)、[签名](https://cloud.tencent.com/document/api/213/30654)。

## 保存、刷新与范围

凭据只在 Android 本机加密账户库保存；余额快照和桌面组件不包含密钥。手机时间错误、密钥错误或权限不足会导致签名/授权失败。刷新失败显示错误并标记旧余额过期，缺少金额不按零处理。不同账户与币种不合计。

本轮仅适配上述两个平台中国站的长期子账户密钥。临时 STS 凭据、国际站、华为云、AWS、Azure 尚未接入，未进行真实账户与真机验收。扩展其他云平台须先核对其独立签名、费用权限、金额单位及账户范围，不能套用模型平台 Bearer Key 查询。
