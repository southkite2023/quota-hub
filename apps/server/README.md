# DeepSeek 余额接入（首版）

此服务只查询 DeepSeek API 余额，不调用模型，不包含订阅和阿里云。需要 Node.js 20+。将两个凭据仅配置在你控制的服务器环境变量中：`DEEPSEEK_API_KEY` 是 DeepSeek 平台的 API Key；`QUOTA_HUB_READ_TOKEN` 是另行生成的随机只读访问令牌，两者必须不同。不要把 `.env`、密钥、令牌或携带令牌的客户端安装包提交到仓库或公开发布。

```sh
cd apps/server
export DEEPSEEK_API_KEY='在服务器终端填写'
export QUOTA_HUB_READ_TOKEN="$(openssl rand -hex 32)"
npm start
```

本地验证：另一个终端向 `http://127.0.0.1:8787/api/v1/snapshot` 发送 `Authorization: Bearer <只读令牌>`。请勿在公开日志里记录 Authorization 头。服务默认只监听本机，客户端跨设备访问时需要你自己的 HTTPS 反向代理和访问控制；不要直接公开 HTTP 端口。服务无跨域响应头，浏览器端尚未作为真实账户入口。

客户端编译时通过 `--dart-define=QUOTA_HUB_URL=https://你的私有服务域名` 和 `--dart-define=QUOTA_HUB_READ_TOKEN=你的只读令牌` 配置个人测试版本。这样令牌会进入安装包，**可以被提取**；只适合你的私人测试安装包，不适合公开分发。生产版应改为登录获取短期、可撤销的只读令牌。不能把 DeepSeek API Key 作为客户端令牌。

服务器最多每五分钟请求一次上游。响应保留每个币种的总余额、赠送余额和充值余额，分别显示，不跨币种相加。上游首次失败为 `error`；已有成功值时失败为 `stale`，重启进程会清空内存缓存。桌面组件在打开应用或点击应用内刷新后更新，没有后台定时刷新。
