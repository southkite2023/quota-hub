# 快照协议 v1

运行 `npm test`（进入本目录）验证全部虚构样例，无外部依赖。入口 `src/index.mjs` 提供 `validateSnapshot`，返回错误列表；空列表代表通过。

一个快照包含 `schemaVersion: 1`、`generatedAt` 和账户数组。账户包含稳定 ID、供应商标识、显示名、`lastSuccessAt` 和指标。指标包含稳定 key、kind、state、value、unit；失败与过期可附错误代码。快照不包含密钥或订阅 URL。

| state | value | 解释 |
| --- | --- | --- |
| ok | 非 null 字符串 | 已知值，数字 `"0"` 是真实零值 |
| unknown | null | 供应商未提供字段或首次查询尚无结果 |
| stale | 非 null 字符串 | 上次成功值，当前更新失败或超出新鲜期 |
| error | null | 查询失败，且没有可展示的旧值 |

`value` 根据 kind 编码：money 为可带负号的十进制字符串（保留供应商实际欠费值，不转为零），unit 为 ISO 4217 三字母币种；traffic 为非负整数字节字符串，unit 固定为 `byte`；expiry 为带时区的 ISO 8601 时间字符串，unit 固定为 `datetime`。金额不得按不同币种求和。流量显示 GB/GiB 时在展示层转换。无限流量与缺失字段不是零：首版不编码“无限”，适配器遇到无限额度时应扩展协议后再接入。

`lastSuccessAt` 记录该账户最近一次成功采集的时间（可为 null）。stale 必须有这个时间；首次失败以 error + null 表达。多个指标可有不同状态；账户整体不可用单一状态覆盖它们。错误代码是公开、可展示的有限枚举，不能包含原始供应商响应或凭据。

见 `fixtures/` 中正常、零值、缺失、过期及首次失败样例。协议变更若破坏现有消费者，需要增加 `schemaVersion`。
